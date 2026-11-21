# OceanSeek image (build and test only)

These recipes import the Operator/Compose images from `oceanbase/ob-operator`
`build/ss`. OceanSeek and LogService each use one image across both deployers.
This directory has no release workflow: the script below builds, tests and saves
local archives without registry login, image pushes, Git tags or GitHub releases.

## Inputs

Use a Docker host with Buildx on an authorized pooled test machine. The default checksum
examples select these amd64 RPMs.

| Component | RPM packages | VERSION |
| --- | --- | --- |
| OceanSeek | `oceanseek`, `oceanseek-libs` | `4.6.3.1-282026111420.al8` |
| LogService | `oblogservice-ce` | `1.3.3-142026112012.el7` |

Obtain the matching RPMs through your authorized artifact channel. Put them in
`oceanseek/rpms/` and `logservice/rpms/`, respectively, then copy each directory's
`SHA256SUMS.example` to `SHA256SUMS`. Verify the hashes against the artifact source.
RPMs and credentials are excluded from Git. Builds fail on missing, extra,
corrupt, symlinked or duplicate RPM inputs, duplicate package names, or an
installed package version that differs from `RPM_VERSION`.

An explicit `HELPER_IMAGE` is required. Use a compatible helper from the same
ob-operator revision as the deployment, pinned by digest or preloaded image ID.
It must provide `/home/admin/oceanbase/bin/oceanbase-helper`, Python 3, and a
GLIBC-compatible system (the original recipe uses Alibaba Cloud Linux 3).
Do not substitute the older Anolis 8 helper base.

To build a helper instead, compile it in the matching ob-operator checkout:

```bash
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -buildvcs=false \
  -o /path/to/docker-images/oceanseek/helper/oceanbase-helper ./cmd/oceanbase-helper
cp LICENSE /path/to/docker-images/oceanseek/helper/LICENSE
```

Then, from the docker-images repository root:

```bash
docker buildx build --load --platform linux/amd64 \
  -f oceanseek/helper/Dockerfile -t local/oceanbase-helper:test .
```

The helper binary and its source LICENSE are caller-supplied, ignored inputs.
`BASE_IMAGE` can override the helper recipe's pinned base digest for the target
architecture. The helper source remains maintained in ob-operator.

## Build, smoke test and archive

From the repository root **on a pooled machine**:

```bash
HELPER_IMAGE=local/oceanbase-helper:test \
  OUTPUT_DIR=/workspace/oceanseek-image-test \
  bash oceanseek/build-test.sh
```

The output directory must be empty. The script builds each image with BuildKit,
checks RPM versions and architecture, helper paths, shared-library resolution,
Observer/LogService version commands, utilities, timezone and container metadata,
then saves two `.tar.gz` Docker archives, image metadata and `SHA256SUMS`.
Load an archive with `gzip -dc oceanseek-amd64.tar.gz | docker load`.
`PLATFORM=linux/arm64` requires matching ARM RPMs, checksum manifests, helper and
base image. For LogService on ARM, copy
`logservice/rpms/SHA256SUMS.arm64.example` to `logservice/rpms/SHA256SUMS`.

For a single component, use the repository root as build context:

```bash
docker buildx build --load --platform linux/amd64 -f oceanseek/Dockerfile \
  --build-arg HELPER_IMAGE=local/oceanbase-helper:test \
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
checksum validation, utility and UTC+8 changes. OceanSeek package names and the
amd64 checksums follow its `20261118-external-deps-dev-r34` build snapshot.
Adaptations here are repository-relative build mounts, explicit helper input and
`oceanseek`/`oceanseek-libs` package checks in place of the older `oceanbase.ai-ce`
names. No changes to ob-operator deployment defaults are included.
