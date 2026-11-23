#!/bin/sh
set -eu
mode=${1:?}
export MC_CONFIG_DIR=/tmp/mc-qa
mc alias set qa http://qa-minio:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" >/dev/null
if [ "$mode" = baseline ]; then
  mkdir -p /work/objects /work/readback
  : > /work/objects/empty
  dd if=/dev/urandom of=/work/objects/small bs=1048576 count=1 2>/dev/null
  dd if=/dev/urandom of=/work/objects/large bs=1048576 count=80 2>/dev/null
  i=0; while [ "$i" -lt 100 ]; do printf 'distributed-object-%s\n' "$i" > "/work/objects/object-$i"; i=$((i+1)); done
  mc mb --ignore-existing qa/distributed >/dev/null
  mc cp --recursive /work/objects/ qa/distributed/ >/dev/null
  (cd /work/objects; sha256sum *) > /work/expected.sha256
fi
if [ "$mode" = offline ]; then
  dd if=/dev/urandom of=/work/objects/during-outage bs=1048576 count=8 2>/dev/null
  mc cp /work/objects/during-outage qa/distributed/during-outage >/dev/null
  printf 'unpatched-outage-object\n' > /work/pending-small
  mc cp /work/pending-small qa/distributed/outage-small >/dev/null
  mv /work/pending-small /work/objects/outage-small
  (cd /work/objects; sha256sum *) > /work/expected.sha256
fi
rm -rf /work/readback
mkdir /work/readback
mc cp --recursive qa/distributed/ /work/readback/ >/dev/null
(cd /work/readback; sha256sum -c /work/expected.sha256) > /work/check-results.txt
expected=$(wc -l < /work/expected.sha256)
actual=$(mc ls --json qa/distributed/ | wc -l)
test "$expected" = "$actual"
printf 'PASS %s: %s objects verified byte-for-byte via SHA256\n' "$mode" "$expected"
