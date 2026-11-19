# No-patch MinIO deployment experiment

Derived from ob-operator charts/oceanbase-minio. This isolated three-node candidate
uses the upstream cluster probe, an independent sidecar admission check, a 1s
MinIO DNS cache refresh and a 10s preStop drain (40s total termination grace).
Set both image values to the matching native architecture of build 44492216536.
No image or chart is published by the test workflow.

Admission alone and drain alone were insufficient on ARM. The combined candidate
passed the scoped follow-up; see [results](../../validation-dns-drain-20261119.md)
and [reproduction](../tests/drain/README.md). It is not a general correctness
promise for arbitrary topology/faults. Existing images and upstream source remain
unchanged. Ordinary clients are not wrapped in the optional retry adapter.

When using `--reuse-values`, set both new values explicitly. For the original
comparison set `shutdownDrainSeconds=0` and `dnsCacheTTL=30s`; `guard.enabled=false`
also disables independent admission. Preserve the existing Secret/PVCs. Upgrading
the template alone does not restart Pods because the chart uses OnDelete.
