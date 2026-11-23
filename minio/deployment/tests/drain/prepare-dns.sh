#!/bin/bash
set -euo pipefail
R=/data/minio-no-patch; export KUBECONFIG=$R/kubeconfig
mkdir -p "$R/evidence-dns"
k() { "$R/tools/k3s" kubectl -n minio-unpatched "$@"; }
k exec mc -- cat /work/expected.sha256 > "$R/evidence-dns/objects-before.sha256"
k get pvc -o json > "$R/evidence-dns/pvc-before.json"
"$R/tools/helm" lint "$R/chart-dns" > "$R/evidence-dns/helm-lint.txt"
"$R/tools/helm" upgrade qa "$R/chart-dns" -n minio-unpatched --reuse-values --set shutdownDrainSeconds=10 --set-string dnsCacheTTL=1s > "$R/evidence-dns/upgrade.txt"
for i in 0 1 2; do k get pod qa-minio-$i -o jsonpath='{.metadata.uid}' > "$R/evidence-dns/old-uid-$i"; done
k delete pods -l app.kubernetes.io/component=minio --wait=false
for i in 0 1 2; do
 for ((j=0;j<150;j++)); do
  new=$(k get pod qa-minio-$i -o jsonpath='{.metadata.uid}' 2>/dev/null || true)
  [[ -n "$new" && "$new" != "$(cat "$R/evidence-dns/old-uid-$i")" ]] && break; sleep 2
 done
 test -n "$new"; test "$new" != "$(cat "$R/evidence-dns/old-uid-$i")"
 k wait pod/qa-minio-$i --for=condition=Ready --timeout=300s
done
k get sts qa-minio -o json > "$R/evidence-dns/sts-dns.json"
k exec -i mc -- sh -s -- upgrade < "$R/objects-dns.sh" | tee -a "$R/evidence-dns/checks.txt"
k exec mc -- cat /work/expected.sha256 | cmp - "$R/evidence-dns/objects-before.sha256"
