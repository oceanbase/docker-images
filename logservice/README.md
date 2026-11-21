# LogService image

This is the `oblogservice-ce` image used alongside OceanSeek by ob-operator and
Compose. See the [shared build and test guide](../oceanseek/README.md) for helper
requirements, checksum-locked RPM inputs, pooled smoke tests and local archives.

Use the repository root as the Docker build context. `VERSION` fixes the tested
RPM version. Download the matching public EL7 RPM for
[x86_64](https://mirrors.oceanbase.com/community/stable/el/7/x86_64/) or
[aarch64](https://mirrors.oceanbase.com/community/stable/el/7/aarch64/).
Copy the matching checksum file (`rpms/SHA256SUMS.example` for amd64 or
`rpms/SHA256SUMS.arm64.example` for arm64) to `rpms/SHA256SUMS`.
The helper must support the `logservice start` subcommand.
The image listens on ports 50051/50052 and defaults to
`/home/admin/oblogservice/bin/oceanbase-helper logservice start`.
There is no publishing workflow for this image.
