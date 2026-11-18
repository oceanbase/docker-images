#!/usr/bin/env bash
set -euo pipefail
image=${1:?image required}
version=${2:?RPM version required}
arch=${3:?amd64 or arm64 required}
case "$arch" in
  amd64) rpm_arch=x86_64 ;;
  arm64) rpm_arch=aarch64 ;;
  *) echo "Unsupported architecture: $arch" >&2; exit 1 ;;
esac
options=(--rm --platform "linux/$arch")
# BuildKit's patched emulator supports ARM subprocesses on pooled x86 hosts
# where installing a system-wide binfmt handler is unavailable.
if [[ "$arch" == arm64 && "$(uname -m)" == x86_64 && -x /usr/bin/buildkit-qemu-aarch64 ]]; then
  options+=(--mount "type=bind,src=/usr/bin/buildkit-qemu-aarch64,dst=/dev/.buildkit_qemu_emulator,readonly"
    --entrypoint /dev/.buildkit_qemu_emulator)
fi
# Variables in the shell program are expanded inside the container.
# shellcheck disable=SC2016
timeout 300 docker run "${options[@]}" "$image" /bin/bash -lc '
  set -euo pipefail
  expected=$1
  rpm_arch=$2
  actual=$(rpm -q --qf "%{VERSION}-%{RELEASE}.%{ARCH}" oceanbase-diagnostic-tool)
  test "$actual" = "$expected.el8.$rpm_arch"
  cli_version=$(obdiag --version)
  printf "%s\n" "$actual" "$cli_version"
  grep -Fxq "OceanBase Diagnostic Tool: ${expected%%-*}" <<< "$cli_version"
  obdiag --help
  obdiag check --help
  obdiag gather --help
  test -s /root/.obdiag/version.yaml
  test -d /root/.obdiag/check
  test -d /root/.obdiag/rca
' -- "$version" "$rpm_arch"
