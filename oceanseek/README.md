# OceanSeek image

These recipes import the Operator/Compose images from `oceanbase/ob-operator`
`build/ss`. OceanSeek and LogService each use one image across both deployers.
Pushing a Git tag named `oceanseek-<version>` or `logservice-<version>` builds
that component for amd64 and arm64 and publishes `:<version>` to Docker Hub,
Quay and GHCR. The release build installs the matching EL7 RPMs from the public
OceanBase mirror. The local build and test flow below uses predownloaded RPMs.

## Inputs

Use a Docker host with Buildx on an authorized pooled test machine. The default checksum
examples select these amd64 RPMs.

| Component | RPM packages | RPM VERSION | Multi-platform image tag |
| --- | --- | --- | --- |
| OceanSeek | `oceanseek`, `oceanseek-libs` | `4.6.3.0-482026112114.el7` | `4.6.3.0-482026112114` |
| LogService | `oblogservice-ce` | `1.3.3-152026112014.el7` | `1.3.3-152026112014` |

The image tag combines the product version and numeric RPM build. One tag covers
`linux/amd64` and `linux/arm64`. The RPM input check uses the full release, including `.el7`.

Download the listed RPMs from the public OceanBase stable EL7 mirror for
[x86_64](https://mirrors.oceanbase.com/community/stable/el/7/x86_64/) or
[aarch64](https://mirrors.oceanbase.com/community/stable/el/7/aarch64/). Put them in
`oceanseek/rpms/` and `logservice/rpms/`, respectively, then copy each directory's
`SHA256SUMS.example` to `SHA256SUMS`. Verify the hashes against the artifact source.
RPMs and credentials are excluded from Git. Builds fail on missing, extra,
corrupt, symlinked or duplicate RPM inputs, duplicate package names, or an
installed package version that differs from `RPM_VERSION`.

Both Dockerfiles select the target platform from the official
`quay.io/oceanbase/oceanbase-helper:2.4.0` image and copy its helper executable
into the pinned Alibaba Cloud Linux 3 runtime. The helper and runtime references
use multi-platform index digests. The bundled helper license comes from
[ob-operator 2.4.0](https://github.com/oceanbase/ob-operator/blob/2.4.0/LICENSE).

## Build, smoke test and archive

From the repository root **on a pooled machine**:

```bash
OUTPUT_DIR=/workspace/oceanseek-image-test \
  bash oceanseek/build-test.sh
```

The output directory must be empty. The script builds each image with BuildKit,
checks RPM versions and architecture, helper paths, shared-library resolution,
Observer/LogService version commands, utilities, timezone and container metadata,
then saves two `.tar.gz` Docker archives, image metadata and `SHA256SUMS`.
Load an archive with `gzip -dc oceanseek-amd64.tar.gz | docker load`.
`PLATFORM=linux/arm64` requires matching ARM RPMs, checksum manifests, and a builder capable
of executing arm64 images. For both components on ARM, use the corresponding
`rpms/SHA256SUMS.arm64.example` as `rpms/SHA256SUMS`.

For a single component, use the repository root as build context:

```bash
docker buildx build --load --platform linux/amd64 -f oceanseek/Dockerfile \
  --build-arg RPM_VERSION="$(cat oceanseek/VERSION)" -t local/oceanseek:test .
```

Use `logservice/Dockerfile`, `logservice/VERSION` and `local/logservice:test` for
the other component. Update VERSION and the checksum manifest together when
changing RPMs. The recipes never download a different product version as fallback.

## Deployment contract and provenance

- OceanSeek: `/home/admin/oceanbase`, ports 2881/2882/2886,
  `oceanbase-helper start`; the image installs obshell 4.5.1.3 from the public OceanBase
  EL7 mirror over the bundled executable. The Dockerfile pins the RPM checksum
  for each architecture and checks the version at the runtime path.
- LogService: `/home/admin/oblogservice`, ports 50051/50052,
  `oceanbase-helper logservice start`.
- Both clear inherited ENTRYPOINT, run as root and use Asia/Shanghai (UTC+8).
  Compose can override CMD with its own scripts; those scripts are maintained in
  ob-operator and are not embedded by these recipes.
- Only OceanSeek's local `etc` owner is changed to match the startup UID. These
  Dockerfiles do not initialize storage, recursively change data-volume ownership,
  or declare anonymous volumes. RPM inputs are read-only build mounts, not image layers.
- The helper requires Kubernetes configuration; the smoke test does not initialize
  it or a database cluster. Full Compose/Helm SQL and recovery tests remain a
  separate deployment acceptance step.

Imported from the ob-operator working snapshot at base commit
`8bfebb94ff12a784ec83c0b7048d45be5665cd7e` on 2026-11-19, including its uncommitted
checksum validation, utility and UTC+8 changes. The RPM checksums for both
architectures come from the public OceanBase stable EL7 repository metadata.
Adaptations here are repository-relative build mounts, the pinned official helper binary and
`oceanseek`/`oceanseek-libs` package checks in place of the older `oceanbase.ai-ce`
names. No changes to ob-operator deployment defaults are included.
