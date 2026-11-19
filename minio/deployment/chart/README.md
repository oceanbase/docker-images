# No-patch MinIO deployment experiment

Derived from ob-operator charts/oceanbase-minio. This isolated candidate uses the
upstream cluster probe and an independent sidecar admission check. See the parent
README for its scope and limitations. `guard.enabled=false` is the standard-probe
baseline for comparison. Set both `image` and `guard.image` to the matching native
architecture build. No chart or image is published by this test workflow.

This candidate did not eliminate false 404 on ARM. It remains an experiment and
is not approved for release; see `../../validation-no-patch-20261119.md`.
