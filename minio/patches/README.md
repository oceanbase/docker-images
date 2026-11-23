# Distributed rejoin patch

`0001-distributed-rejoin.patch` is an OceanBase modification of the pinned MinIO
source, adapted from ob-operator's `scripts/lakehouse/images/minio-rejoin/rejoin.patch`.
It is included in the source/build archive, along with the original upstream archive
and the complete patched source. `docs/patch-sha256sums.txt` identifies its contents.
The standalone mc source is unchanged. Both images retain the approved bilingual notice.

- Restore the unauthenticated GET/HEAD `/minio/health/lakehouse-ready` contract used
  by the ob-operator distributed Helm chart. For its single-pool, single-set,
  three-drive layout, a new process is admitted only after all three current disk
  endpoints respond, including authenticated peer health. After admission, normal
  write quorum governs availability so a single-node outage does not remove the
  surviving servers from service. Admission resets on process restart.
- When latest-version merging reports absence despite a successful metadata read,
  an unavailable disk, and no majority establishing absence, return a retryable
  insufficient-read-quorum error (HTTP 503), not a false NoSuchKey (HTTP 404).
  Genuine majority-confirmed absence still returns 404.

The custom endpoint intentionally returns 503 for other layouts. Use the standard
MinIO readiness/cluster endpoints for those layouts. This gate does not guarantee
zero transient transport errors during a node transition or physical-host HA.

Native CI runs the outage-write regression against the original object-read code
(must reproduce the false 404), restores the patched file, and runs the quorum and
admission regressions. Runtime validation must additionally exercise distributed
reads, outage writes, rejoin and persistent-volume restarts on authorized machines.
