# LogService image

This is the `oblogservice-ce` image used alongside OceanSeek by ob-operator and
Compose. See the [shared build and test guide](../oceanseek/README.md) for helper
requirements, checksum-locked RPM inputs, pooled smoke tests and local archives.

Use the repository root as the Docker build context. `VERSION` fixes the tested
RPM version and `rpms/SHA256SUMS.example` fixes the amd64 input checksum.
The image listens on ports 50051/50052 and defaults to
`/home/admin/oblogservice/bin/oceanbase-helper logservice start`.
There is no publishing workflow for this image.
