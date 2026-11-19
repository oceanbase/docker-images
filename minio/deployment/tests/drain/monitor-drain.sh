#!/bin/sh
set -eu
mode=${1:?}; end=$(( $(date +%s) + 2400 )); n=0
while [ ! -f "/work/$mode.stop" ] && [ "$(date +%s)" -lt "$end" ]; do
 n=$(( (n+1) % 100 ))
 for object in "object-$n" outage-small outage-small-drain; do
  [ -f "/work/objects/$object" ] || continue
  if [ "$mode" = raw ]; then
   code=$(curl -sS --max-time 4 --aws-sigv4 aws:amz:us-east-1:s3 --user "$MINIO_ROOT_USER:$MINIO_ROOT_PASSWORD" -o /work/raw-body -w '%{http_code}' "http://qa-minio:9000/distributed/$object" 2>/dev/null) || code=000
   result=$code
   if [ "$code" = 200 ]; then cmp -s "/work/objects/$object" /work/raw-body || result=CORRUPTION; fi
   printf '%s %s %s\n' "$(date +%s)" "$object" "$result"
  else
   sha=$(sha256sum "/work/objects/$object" | cut -d' ' -f1)
   export S3_ACCESS_KEY="$MINIO_ROOT_USER" S3_SECRET_KEY="$MINIO_ROOT_PASSWORD"
   rc=0
   /usr/local/bin/known-object-get.sh "http://qa-minio:9000/distributed/$object" "$sha" /work/adapter-body 2>/work/adapter-attempts || rc=$?
   printf '%s %s exit=%s attempts=%s\n' "$(date +%s)" "$object" "$rc" "$(wc -l < /work/adapter-attempts)"
   cat /work/adapter-attempts
  fi
 done
 sleep 0.1
done
: > "/work/$mode.finished"
