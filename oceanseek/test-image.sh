#!/usr/bin/env bash
set -euo pipefail
component=${1:?component}
image=${2:?image}
version=${3:?RPM version}
arch=${4:?architecture}
case "$component" in
  oceanseek)
    directory=/home/admin/oceanbase
    package=oceanseek
    command='["/home/admin/oceanbase/bin/oceanbase-helper","start"]'
    ports='{"2881/tcp":{},"2882/tcp":{},"2886/tcp":{}}'
    ;;
  logservice)
    directory=/home/admin/oblogservice
    package=oblogservice-ce
    command='["/home/admin/oblogservice/bin/oceanbase-helper","logservice","start"]'
    ports='{"50051/tcp":{},"50052/tcp":{}}'
    ;;
  *) exit 2;;
esac
test "$(docker image inspect -f '{{.Architecture}}' "$image")" = "$arch"
test "$(docker image inspect -f '{{.Config.User}}' "$image")" = root
test "$(docker image inspect -f '{{.Config.WorkingDir}}' "$image")" = "$directory"
test "$(docker image inspect -f '{{json .Config.Cmd}}' "$image")" = "$command"
test "$(docker image inspect -f '{{json .Config.ExposedPorts}}' "$image")" = "$ports"
for field in Entrypoint Volumes; do
  value=$(docker image inspect -f "{{json .Config.$field}}" "$image")
  [[ "$value" = null || "$value" = '[]' || "$value" = '{}' ]]
done
docker run --rm --platform "linux/$arch" --entrypoint /bin/bash "$image" -ceu '
  component=$1; package=$2; version=$3; directory=$4; arch=$5
  test "$(rpm -q --qf "%{VERSION}-%{RELEASE}" "$package")" = "$version"
  case "$arch" in amd64) rpm_arch=x86_64;; arm64) rpm_arch=aarch64;; esac
  test "$(rpm -q --qf "%{ARCH}" "$package")" = "$rpm_arch"
  test "$TZ" = Asia/Shanghai
  test "$(date +%z)" = +0800
  test "$(readlink /etc/localtime)" = /usr/share/zoneinfo/Asia/Shanghai
  for tool in tar pgrep ps; do command -v "$tool"; done
  tar --version
  ps -p $$
  pgrep -x bash
  python3 -c "import json, tarfile, gzip, pathlib, subprocess, tempfile"
  . /etc/os-release
  test "$ID" = alinux
  test "${VERSION_ID%%.*}" = 3
  "$directory/bin/oceanbase-helper" --help >/dev/null
  "$directory/bin/oceanbase-helper" logservice start --help >/dev/null
  test ! -e /tmp/verify-rpms.py
  test -z "$(find /tmp /var/cache/yum -name \*.rpm -print -quit 2>/dev/null)"
  if [[ "$component" = oceanseek ]]; then
    binary="$directory/bin/observer"
    test "$(rpm -q --qf "%{VERSION}-%{RELEASE}.%{ARCH}" obshell)" = "4.5.1.3-12026111915.el7.$rpm_arch"
    test "$("$directory/bin/obshell" version)" = "4.5.1.3-12026111915"
    test "$(rpm -q --qf "%{VERSION}-%{RELEASE}" oceanseek-libs)" = "$version"
    test "$(stat -c %u "$directory/etc")" = "$(id -u)"
    "$binary" -V
  else
    binary="$directory/bin/oblogservice"
    test "$(readlink "$directory/bin/oceanbase-helper")" = /home/admin/oceanbase/bin/oceanbase-helper
    "$binary" --version
  fi
  dependencies=$(ldd "$binary")
  printf "%s\n" "$dependencies"
  [[ "$dependencies" != *"not found"* ]]
' -- "$component" "$package" "$version" "$directory" "$arch"
echo "PASS: $component ($arch)"
