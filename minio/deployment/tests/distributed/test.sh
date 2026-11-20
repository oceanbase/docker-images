#!/bin/bash
set -euo pipefail
R=/data/minio-no-patch; cd "$R"
export KUBECONFIG=$R/kubeconfig
ns=minio-unpatched; build=44492216536
stage=${1:?}; arch=${2:?}; E=$R/evidence
k() { "$R/tools/k3s" kubectl "$@"; }
kn() { k -n "$ns" "$@"; }
pass() { echo "PASS $*" | tee -a "$E/checks.txt"; }
objects() { timeout 180 "$R/tools/k3s" kubectl -n "$ns" exec -i mc -- sh -s -- "$1" < "$R/objects.sh" | tee -a "$E/checks.txt"; }
waitpods() {
 local i retry
 for i in 0 1 2; do
  for ((retry=0;retry<90;retry++)); do kn get pod "qa-minio-$i" >/dev/null 2>&1 && break; sleep 2; done
  kn wait "pod/qa-minio-$i" --for=condition=Ready --timeout=300s
 done
}
info() { timeout 120 "$R/tools/k3s" kubectl -n "$ns" exec mc -- mc --config-dir /tmp/mc-qa admin info --json qa > "$E/admin-$1.json"; }
identity() {
 mkdir -p "$E/identity"
 kn get pods -o json > "$E/pods.json"
 for i in 0 1 2; do
  kn exec "qa-minio-$i" -c minio -- sha256sum /usr/bin/minio /usr/bin/mc > "$E/identity/minio-$i.sha256"
  cmp "expected-$arch.txt" "$E/identity/minio-$i.sha256"
  kn exec "qa-minio-$i" -c minio -- cat /usr/share/doc/oceanbase-minio/NOTICE.txt > "$E/identity/NOTICE-$i.txt"
  cmp NOTICE.txt "$E/identity/NOTICE-$i.txt"
  kn exec "qa-minio-$i" -c minio -- cat /usr/share/doc/oceanbase-minio/SOURCE-CODE.txt > "$E/identity/SOURCE-$i.txt"
  grep -q "actions/runs/$build" "$E/identity/SOURCE-$i.txt"
 done
 kn exec mc -- sha256sum /usr/bin/mc > "$E/identity/mc.sha256"
 tail -1 "expected-$arch.txt" | cmp - "$E/identity/mc.sha256"
 kn exec mc -- cat /usr/share/doc/oceanbase-minio/NOTICE.txt > "$E/identity/NOTICE-mc.txt"
 cmp NOTICE.txt "$E/identity/NOTICE-mc.txt"
 pass "all native MinIO/mc binaries and notices match unmodified-source build $build"
}
monitor_start() {
 kn exec -i mc -- sh -c 'cat > /work/monitor.sh; rm -f /work/raw.stop /work/raw.finished /work/adapter.stop /work/adapter.finished' < monitor.sh
 for mode in raw adapter; do kn exec mc -- sh -c "nohup sh /work/monitor.sh $mode > /work/$mode.log 2>&1 < /dev/null &"; done
}
monitor_stop() {
 local phase=$1
 kn exec mc -- touch /work/raw.stop /work/adapter.stop
 for mode in raw adapter; do
  for ((retry=0;retry<40;retry++)); do kn exec mc -- test -f "/work/$mode.finished" && break; sleep 1; done
  kn exec mc -- test -f "/work/$mode.finished"
  kn exec mc -- cat "/work/$mode.log" > "$E/$phase-$mode.log"
 done
 awk '{count[$3]++} END {for(c in count) print c,count[c]}' "$E/$phase-raw.log" | sort | tee "$E/$phase-raw-summary.txt"
}
case "$stage" in
install)
 k wait nodes --all --for=condition=Ready --timeout=240s
 "$R/tools/helm" upgrade --install qa chart -n "$ns" --create-namespace --set guard.enabled=false \
  --set-string image="minio:test-$build-$arch" --set-string guard.image="minio-mc:test-$build-$arch" \
  --set resources.limits.memory=2Gi > "$E/install.txt"
 waitpods
 prefix=x86; [[ "$arch" == arm64 ]] && prefix=arm
 cat > client.yaml <<YAML
apiVersion: v1
kind: Pod
metadata: {name: mc, namespace: $ns}
spec:
  nodeSelector: {kubernetes.io/hostname: ${prefix}-node0}
  automountServiceAccountToken: false
  securityContext: {runAsUser: 10001, runAsGroup: 10001, fsGroup: 10001}
  containers:
    - name: mc
      image: minio-mc:test-$build-$arch
      imagePullPolicy: Never
      command: [/bin/sh, -c, 'sleep 86400']
      securityContext: {readOnlyRootFilesystem: true, allowPrivilegeEscalation: false}
      env:
        - name: MINIO_ROOT_USER
          valueFrom: {secretKeyRef: {name: qa-minio-root, key: rootUser}}
        - name: MINIO_ROOT_PASSWORD
          valueFrom: {secretKeyRef: {name: qa-minio-root, key: rootPassword}}
        - {name: MC_UPDATE, value: 'off'}
      volumeMounts: [{name: work, mountPath: /work}, {name: tmp, mountPath: /tmp}]
  volumes: [{name: work, emptyDir: {}}, {name: tmp, emptyDir: {}}]
YAML
 k apply -f client.yaml
 kn wait pod/mc --for=condition=Ready --timeout=180s
 objects baseline
 identity
 info baseline
 kn get pvc -o json > "$E/pvc-before.json"
 kn exec mc -- cat /work/expected.sha256 > "$E/objects-before.sha256"
 ;;
baseline)
 monitor_start
 for round in 1 2; do
  for i in 0 1 2; do
   kn delete pod "qa-minio-$i" --wait=true
   waitpods
   objects "baseline-$round-pod-$i" || echo "OBSERVED baseline read failure round=$round pod=$i" | tee -a "$E/checks.txt"
  done
 done
 monitor_stop baseline
 sleep 5
 objects baseline-final
 ;;
enable-guard)
 "$R/tools/helm" upgrade qa chart -n "$ns" --reuse-values --set guard.enabled=true > "$E/guard-upgrade.txt"
 kn delete pods -l app.kubernetes.io/component=minio --wait=true
 waitpods
 kn get sts qa-minio -o json > "$E/sts-guard.json"
 objects guard-enabled
 kn exec mc -- cat /work/expected.sha256 | cmp - "$E/objects-before.sha256"
 pass 'upper-layer admission ready; all original data preserved'
 ;;
monitor-start) monitor_start;;
offline)
 prefix=x86; [[ "$arch" == arm64 ]] && prefix=arm
 for ((retry=0;retry<90;retry++)); do
  ready=$(k get node "$prefix-node2" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
  [[ "$ready" != True ]] && break; sleep 2
 done
 test "$ready" != True
 objects offline
 info offline
 k get nodes -o wide > "$E/nodes-offline.txt"
 pass 'one node offline; existing and new objects verified'
 ;;
recovered)
 k wait nodes --all --for=condition=Ready --timeout=240s
 waitpods
 objects recovered
 info recovered
 ;;
cycles)
 for round in 1 2 3; do
  for i in 0 1 2; do
   start=$(date +%s)
   old=$(kn get pod "qa-minio-$i" -o jsonpath='{.metadata.uid}')
   kn delete pod "qa-minio-$i" --wait=true
   waitpods
   test "$old" != "$(kn get pod "qa-minio-$i" -o jsonpath='{.metadata.uid}')"
   echo "round=$round pod=$i recovery_seconds=$(( $(date +%s)-start ))" >> "$E/recovery-times.txt"
   objects "round-$round-pod-$i"
  done
 done
 ;;
samepod)
 guard_before=$(kn get pod qa-minio-2 -o jsonpath='{.status.containerStatuses[?(@.name=="deployment-guard")].restartCount}')
 kn get pod qa-minio-2 -o json > "$E/samepod-before.json"
 before=$(kn get pod qa-minio-2 -o jsonpath='{.status.containerStatuses[?(@.name=="minio")].restartCount}')
 uid=$(kn get pod qa-minio-2 -o jsonpath='{.metadata.uid}')
 # The sidecar observes the old process identity; kill only this Pod's MinIO.
 kn exec qa-minio-2 -c minio -- sh -c 'for f in /proc/[0-9]*/comm; do if [ "$(cat "$f" 2>/dev/null)" = minio ]; then p=${f#/proc/}; p=${p%/comm}; kill -KILL "$p"; fi; done' || true
 for ((retry=0;retry<120;retry++)); do
  after=$(kn get pod qa-minio-2 -o jsonpath='{.status.containerStatuses[?(@.name=="minio")].restartCount}')
  [[ "$after" -gt "$before" ]] && break; sleep 1
 done
 test "$after" -gt "$before"
 waitpods
 test "$uid" = "$(kn get pod qa-minio-2 -o jsonpath='{.metadata.uid}')"
 for ((retry=0;retry<90;retry++)); do
  kn logs qa-minio-2 -c deployment-guard > "$E/samepod-guard.log"
  admissions=$(awk '/ready=true/ {for(i=1;i<=NF;i++) if($i ~ /^process=/) print $i}' "$E/samepod-guard.log" | sort -u | wc -l)
  [[ "$admissions" -ge 2 ]] && break; sleep 1
 done
 test "$admissions" -ge 2
 test "$guard_before" = "$(kn get pod qa-minio-2 -o jsonpath='{.status.containerStatuses[?(@.name=="deployment-guard")].restartCount}')"
 kn get pod qa-minio-2 -o json > "$E/samepod-after.json"
 objects same-pod-minio-process-restart
 pass 'same Pod MinIO process restart recovered with independent guard still running'
 ;;
monitor-stop) monitor_stop guarded;;
full-restart)
 kn scale sts/qa-minio --replicas=0
 kn wait pod -l app.kubernetes.io/component=minio --for=delete --timeout=180s
 kn get pvc -o json > "$E/pvc-stopped.json"
 sleep 5
 kn scale sts/qa-minio --replicas=3
 waitpods
 objects full-restart
 info final
 identity
 kn get pvc -o json > "$E/pvc-after.json"
 kn exec mc -- cat /work/expected.sha256 > "$E/objects-final.sha256"
 kn exec mc -- cat /work/check-results.txt > "$E/object-checks-final.txt"
 for i in 0 1 2; do
  kn logs "qa-minio-$i" -c deployment-guard > "$E/guard-$i.log"
  kn logs "qa-minio-$i" -c minio > "$E/minio-$i.log"
  printf 'pod%s ' "$i" >> "$E/storage-counts.txt"
  kn exec "qa-minio-$i" -c minio -- sh -c 'find /data/distributed -name xl.meta | wc -l' >> "$E/storage-counts.txt"
 done
 kn get events --sort-by=.metadata.creationTimestamp > "$E/events.txt"
 k get nodes -o wide > "$E/nodes-final.txt"
 kn get pods,pvc -o wide > "$E/resources-final.txt"
 ;;
*) exit 2;;
esac
