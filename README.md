# OceanBase Docker Images

This repository contains [Dockerfiles](https://docs.docker.com/engine/reference/builder/) and samples to build [Docker](https://www.docker.com/what-docker) images for OceanBase products.

## Available Images

- **oceanbase-ce**: OceanBase Community Edition database server
- **obproxy-ce**: OceanBase connection proxy
- **obagent**: OceanBase monitoring agent
- **obdiag**: OceanBase diagnostic tool
- **ob-configserver**: OceanBase configuration server
- **obbinlog-ce**: OceanBase database with binlog service (includes Observer, OBProxy, and Binlog components)
- **oceanbase-cloud-native**: Cloud-native optimized OceanBase version

## obdiag Images

`obdiag/VERSION` locks the RPM to **5.0.2-12026102116** (el8). Build with
`docker build -t obdiag:local ./obdiag`. An optional `VERSION` build argument
must match this lock; the build verifies the installed RPM version.

The release flow follows oceanbase-ce's separate version and latest entry points:

- `obdiag-5.0.2-12026102116` publishes `5.0.2-12026102116`.
- `latest-obdiag-5.0.2-12026102116` publishes that version and promotes `latest`.
- Both tags must match `obdiag/VERSION`. To release another RPM, update the lock
  in the tagged commit first. Normal releases never update `latest`.

Both release paths require successful amd64 and arm64 builds and smoke tests
(RPM version/architecture, CLI version/help, check/gather help and initialized
configuration). The release job downloads and publishes the tested image archives
without rebuilding them. Release image archives are retained for 7 days; branch
and manual test archives are retained for 1 day. Both release entry points share
a serial queue with up to 100 pending runs, so new releases do not replace an
existing pending release while the queue has capacity. Docker Hub, Quay and GHCR
receive the multi-platform version tag and supporting `<version>-amd64` / `<version>-arm64` tags.

Branch pushes affecting obdiag and manual runs of `test-obdiag.yml` only build,
test and upload short-lived Actions artifacts; they never log into or push to
any image registry. Tests run exclusively on a pooled self-hosted runner with
labels `self-hosted`, `linux`, `x64`, `obdiag-test`. A repository administrator
must register this runner before enabling the workflows. It needs Bash, Docker
(accessible to the runner user), Buildx, and ARM64 emulation (binfmt or
`/usr/bin/buildkit-qemu-aarch64`). Use isolated pooled machines; no
`pull_request` trigger is configured to execute untrusted fork code on them.

Publishing uses the same `DOCKER_USERNAME`, `DOCKER_PASSWORD`,
`QUAY_IO_USERNAME`, `QUAY_IO_PASSWORD` secrets and `DOCKER_PUSH_BASE`,
`QUAY_IO_PUSH_BASE` variables as the other image releases. GHCR uses
`GITHUB_TOKEN` with `packages: write`. Ensure the Quay and GHCR repositories
are public for anonymous pulls. The original obdiag repository also publishes
Docker Hub tags; coordinate `latest` promotion between the repositories.
