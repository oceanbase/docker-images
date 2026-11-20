# No-patch deployment candidate

**Test only; no release.** Admission alone returned false 404 on ARM. The current
Helm candidate additionally refreshes upstream DNS every second and drains for
ten seconds before SIGTERM. Both native architectures passed the scoped follow-up
without false 404; this does not change or prove correctness of upstream quorum
logic for every failure mode. See [the latest results](../validation-dns-drain-20261119.md).

MinIO and mc upstream source files remain unchanged. `verify-upstream.py` compares
all original archive files after vendoring and compilation. Historical patches in
`../patches` are not applied or included in the current build recipe/source bundle.

The mc image additionally carries an independent Apache-2.0 `deployment-guard`
binary and `known-object-get.sh`. These use the normal HTTP/S3/admin interfaces and
mc executable; no MinIO source or Go library is linked into the helper. Their code,
license and tests are included in the source/build archive under recipe/deployment.

Use a guard sidecar with the mc image, `/usr/local/bin/deployment-guard`, a writable
/tmp, the same MinIO credentials, and `shareProcessNamespace: true`. Its HTTP
readiness endpoint is :8080/ready. The MinIO container itself uses the standard
/minio/health/cluster probe. Peer discovery must continue to publish not-ready
addresses; the business Service must only route to Ready Pods.

Admission requires three consecutive successful rounds: three online drives,
all three peer connectivity matrices online, server uptimes at least 15 seconds,
and a real PUT followed by GET via each peer with exact payload comparison.
Each process gets its own canary in a private deployment-guard-health bucket.
The canary is removed after admission. The guard polls the MinIO PID/starttime
in the shared process namespace and repeats admission when it observes a changed
process. Polling and Kubernetes endpoint updates are asynchronous; they do not
guarantee instant withdrawal from every traffic path. After admission, surviving nodes use normal write-quorum
health; losing one peer does not automatically remove all surviving nodes.

This is an experiment, not proof that external admission can fix MinIO's internal
object quorum decisions. Raw signed GETs must be recorded without client retries
throughout node outage/rejoin, Pod recreation and full stop/start. Genuine missing
objects must still return 404. A simple sleep or a successful canary is not a
proof that every object is readable. No automatic healing or data rewrite is used
to hide failures in verification.

`known-object-get.sh URL EXPECTED_SHA256 DESTINATION` is an optional, explicitly
invoked adapter for callers with an authoritative hash of an existing immutable
object. It retries only GET (up to 5 attempts, each limited to 3 seconds), verifies
the content and atomically replaces the destination. Exhaustion returns exit 75;
403 and content mismatch fail immediately. It never guesses whether an arbitrary
404 is genuine. Ordinary clients and database read paths are not automatically
wrapped by this script. S3_ACCESS_KEY, S3_SECRET_KEY and optional S3_REGION are
environment variables. Retry logs expose neither credentials nor signed URLs.

Credentials used for admin checks are privileged. This candidate reuses the
existing Secret inside the Pod, without adding network routes or exposing a new
S3 proxy. A separate least-privilege probe account requires additional validation.

The isolated [Helm candidate](chart/README.md) is derived from ob-operator's
MinIO chart. Its defaults reference the AMD64 test images from run 44492216536;
set both image values to the ARM64 tags when testing ARM. It is a fixed
three-server, one-drive-per-server HTTP experiment, not a general-purpose
production chart. The current guard deliberately checks this exact topology.
The tested Helm chart and [distributed harness](tests/distributed/README.md) were
added after the image build; obtain them from this repository, not from the
earlier build's source archive. See [measured results](../validation-no-patch-20261119.md)
for the baseline, direct GET and explicit adapter results.

The Helm values `dnsCacheTTL: 1s` and `shutdownDrainSeconds: 10` use existing
upstream behavior. The Pod termination grace period is 30 seconds plus the drain
interval. On an existing release use explicit `--set-string dnsCacheTTL=1s
--set shutdownDrainSeconds=10` with `--reuse-values`, and recreate Pods deliberately
because the StatefulSet uses OnDelete. This increases DNS refresh frequency and
planned shutdown latency. PreStop is bypassed by SIGKILL, power loss or forced
zero-grace deletion. Transient unavailability and startup retries still occur.
