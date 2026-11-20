#!/bin/bash
set -euo pipefail
R=/data/minio-no-patch; export KUBECONFIG=$R/kubeconfig
mkdir -p "$R/evidence-drain"
k() { "$R/tools/k3s" kubectl -n minio-unpatched "$@"; }
k exec mc -- cat /work/expected.sha256 > "$R/evidence-drain/objects-before.sha256"
k get pvc -o json > "$R/evidence-drain/pvc-before.json"
"$R/tools/helm" lint "$R/chart-drain" > "$R/evidence-drain/helm-lint.txt"
"$R/tools/helm" upgrade qa "$R/chart-drain" -n minio-unpatched --reuse-values --set shutdownDrainSeconds=10 --set-string dnsCacheTTL=30s > "$R/evidence-drain/upgrade.txt"
for i in 0 1 2; do k get pod qa-minio-$i -o jsonpath='{.metadata.uid}' > "$R/evidence-drain/old-uid-$i"; done
k delete pods -l app.kubernetes.io/component=minio --wait=false
for i in 0 1 2; do
 for ((j=0;j<150;j++)); do
  new=$(k get pod qa-minio-$i -o jsonpath='{.metadata.uid}' 2>/dev/null || true)
  [[ -n "$new" && "$new" != "$(cat "$R/evidence-drain/old-uid-$i")" ]] && break; sleep 2
 done
 test -n "$new"; test "$new" != "$(cat "$R/evidence-drain/old-uid-$i")"
 k wait pod/qa-minio-$i --for=condition=Ready --timeout=300s
done
k get sts qa-minio -o json > "$R/evidence-drain/sts-drain.json"
k exec -i mc -- sh -s -- upgrade < "$R/objects-drain.sh" | tee -a "$R/evidence-drain/checks.txt"
k exec mc -- cat /work/expected.sha256 | cmp - "$R/evidence-drain/objects-before.sha256"
