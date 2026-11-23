#!/usr/bin/env bash
set -euo pipefail

if [[ -n ${VERSION:-} ]]; then
    arch=$(rpm --eval '%{_arch}')
    mirror="https://mirrors.oceanbase.com/community/stable/el/7/$arch"
    packages=()
    for name in "$@"; do
        packages+=("$mirror/$name-$RPM_VERSION.$arch.rpm")
    done
else
    cd /tmp/rpms
    python3 /tmp/verify-rpms.py .
    duplicates=$(rpm -qp --qf '%{NAME}\n' ./*.rpm | sort | uniq -d)
    test -z "$duplicates"
    packages=(./*.rpm)
fi

yum --disablerepo='*' install -y tar procps-ng "${packages[@]}" ||
    yum install -y tar procps-ng "${packages[@]}"
