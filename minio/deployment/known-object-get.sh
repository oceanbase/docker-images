#!/bin/bash
# Apache-2.0. Optional adapter for a caller holding an authoritative expected hash.
set -euo pipefail
url=${1:?URL required}; expected=${2:?trusted expected SHA256 required}; destination=${3:?destination required}
[[ "$expected" =~ ^[0-9a-f]{64}$ ]] || exit 2
: "${S3_ACCESS_KEY:?}" "${S3_SECRET_KEY:?}"
tmp=$(mktemp "${destination}.partial.XXXXXX")
trap 'rm -f "$tmp"' EXIT
for attempt in 1 2 3 4 5; do
  code=$(curl --silent --show-error --connect-timeout 2 --max-time 3 \
    --aws-sigv4 "aws:amz:${S3_REGION:-us-east-1}:s3" --user "$S3_ACCESS_KEY:$S3_SECRET_KEY" \
    -o "$tmp" -w '%{http_code}' "$url" 2>/dev/null) || code=000
  printf 'attempt=%s http=%s\n' "$attempt" "$code" >&2
  if [[ "$code" == 200 ]]; then
    [[ "$(sha256sum "$tmp" | cut -d' ' -f1)" == "$expected" ]] || exit 1
    mv "$tmp" "$destination";exit 0
  fi
  case "$code" in 000|404|429|500|502|503|504) ;; *) exit 1;; esac
  [[ "$attempt" == 5 ]] || sleep 1
done
# Known object temporarily unavailable; never manufacture a successful/missing result.
exit 75
