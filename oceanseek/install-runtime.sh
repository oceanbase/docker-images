#!/usr/bin/env bash
set -eu
yum install -y bash coreutils findutils procps-ng tar gzip shadow-utils tzdata \
    libgcc libstdc++ zlib python3
yum clean all
if ! id admin >/dev/null 2>&1; then
    useradd -m -s /bin/bash admin
fi
ln -snf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
