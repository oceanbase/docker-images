#!/bin/sh
set -eu
export MC_CONFIG_DIR=/tmp/mc-qa
for i in 0 1 2; do
 mc alias set "trace$i" "http://qa-minio-$i.qa-minio-peer.minio-unpatched.svc:9000" "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" >/dev/null
 (while [ ! -f /work/trace.stop ]; do mc --json admin trace --method GET --path 'distributed/*' --node "qa-minio-$i*" "trace$i" || true; sleep 1; done) > "/work/trace-$i.json" 2>"/work/trace-$i.err" &
done
wait
