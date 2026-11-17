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

Build locally with `docker build -f obdiag/Dockerfile -t obdiag:local obdiag`.

Pushing a tag such as `obdiag-v5.0.1` triggers `.github/workflows/release-obdiag.yml`,
which builds Linux amd64 and arm64 images and publishes `v5.0.1` and `latest`
to Docker Hub, Quay, and GHCR. It uses the same `DOCKER_USERNAME`,
`DOCKER_PASSWORD`, `QUAY_IO_USERNAME`, `QUAY_IO_PASSWORD` secrets and
`DOCKER_PUSH_BASE`, `QUAY_IO_PUSH_BASE` variables as the other image releases;
GHCR uses the workflow's `GITHUB_TOKEN` with `packages: write` permission.
Ensure the Quay and GHCR repositories are public for anonymous pulls.

The Dockerfile is copied from `oceanbase/obdiag`'s `dockerfiles/Dockerfile.release`.
It installs `oceanbase-diagnostic-tool` from the OceanBase yum repository without
pinning the RPM version. The release tag names the image; it does not select the
RPM version or build obdiag source code. Confirm the yum package version before
publishing a release. The original obdiag repository also publishes the Docker
Hub `obdiag` tags, so coordinate releases to avoid overwriting the same tags.
