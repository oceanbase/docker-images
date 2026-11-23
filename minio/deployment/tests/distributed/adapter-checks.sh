#!/bin/bash
set -euo pipefail
export S3_ACCESS_KEY="$MINIO_ROOT_USER" S3_SECRET_KEY="$MINIO_ROOT_PASSWORD"
url=http://qa-minio:9000/distributed/object-1
sha=$(sha256sum /work/objects/object-1 | cut -d' ' -f1)
get=/usr/local/bin/known-object-get.sh
$get "$url" "$sha" /work/check-good 2>/work/check-attempts
cmp /work/check-good /work/objects/object-1
echo 'PASS adapter known-object success and checksum'
rc=0
$get "$url" "$(printf '%064d' 0)" /work/check-mismatch 2>/work/check-attempts || rc=$?
test "$rc" = 1; test ! -e /work/check-mismatch; test "$(wc -l < /work/check-attempts)" = 1
echo 'PASS adapter content mismatch rejected without retry/output'
rc=0
S3_SECRET_KEY=deliberately-invalid $get "$url" "$sha" /work/check-denied 2>/work/check-attempts || rc=$?
test "$rc" = 1; test ! -e /work/check-denied; test "$(wc -l < /work/check-attempts)" = 1
grep -q 'http=403' /work/check-attempts
echo 'PASS adapter bad credentials 403 rejected without retry/output'
missing=http://qa-minio:9000/distributed/never-created-negative-control
code=$(curl -sS --max-time 5 --aws-sigv4 aws:amz:us-east-1:s3 --user "$MINIO_ROOT_USER:$MINIO_ROOT_PASSWORD" -o /work/missing-body -w '%{http_code}' "$missing")
test "$code" = 404; grep -q NoSuchKey /work/missing-body
echo 'PASS genuine absent object remains HTTP404/NoSuchKey'
start=$(date +%s); rc=0
$get "$missing" "$sha" /work/check-exhausted 2>/work/check-attempts || rc=$?
test "$rc" = 75; test ! -e /work/check-exhausted; test "$(wc -l < /work/check-attempts)" = 5
test "$(( $(date +%s)-start ))" -le 22
echo 'PASS adapter exhausted returns temporary-unavailable exit75 after 5 attempts, no false success'
