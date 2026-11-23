#!/usr/bin/env bash
# Run only on an authorized pooled test machine. Never publishes images.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${OUTPUT_DIR:?Set OUTPUT_DIR to an empty directory for test artifacts}"
platform=${PLATFORM:-linux/amd64}
arch=${platform#linux/}
case "$arch" in amd64|arm64) ;; *) echo "Unsupported platform: $platform" >&2; exit 1;; esac
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR=$(cd "$OUTPUT_DIR" && pwd)
if [[ -n $(ls -A "$OUTPUT_DIR") ]]; then
  echo 'OUTPUT_DIR must be empty' >&2; exit 1
fi
python3 -m unittest discover -s oceanseek -p 'test_*.py' -v
for component in oceanseek logservice; do
  version=$(cat "$component/VERSION")
  image="local/$component:test-$version-$arch"
  docker buildx build --load --platform "$platform" \
    --build-arg "RPM_VERSION=$version" \
    -f "$component/Dockerfile" -t "$image" .
  bash oceanseek/test-image.sh "$component" "$image" "$version" "$arch"
  docker image inspect "$image" > "$OUTPUT_DIR/$component.image.json"
  docker save "$image" | gzip > "$OUTPUT_DIR/$component-$arch.tar.gz"
done
(cd "$OUTPUT_DIR" && sha256sum ./*.tar.gz > SHA256SUMS)
echo "Tested image archives: $OUTPUT_DIR"
