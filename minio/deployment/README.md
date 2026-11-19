# No-patch deployment candidate

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
The canary is removed after admission. The guard observes the MinIO PID/starttime
in the shared process namespace so a same-Pod process restart cannot reuse an old
admission decision. After admission, surviving nodes use normal write-quorum
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
