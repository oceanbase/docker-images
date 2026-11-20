#!/usr/bin/env bash
set -euo pipefail
recipe=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
arch=${1:?Usage: build.sh amd64|arm64 NEW_OUTPUT_DIRECTORY SERVER_IMAGE CLIENT_IMAGE}
out=${2:?new output directory required}
server=${3:?local server image required}
client=${4:?local client image required}
case "$arch/$(uname -m)" in amd64/x86_64|arm64/aarch64) ;; *) echo 'Use a native runner for the requested architecture' >&2; exit 1;; esac
test ! -e "$out"
mkdir -p "$out"
out=$(cd "$out" && pwd)
mkdir -p "$out"/{src,bin,logs,docs,licenses,upstream,recipe,toolchain}
cp "$recipe"/{Dockerfile,versions.json,build.sh,test.sh,verify-upstream.py,collect-notices.py,README.md,NOTICE.txt} "$out/recipe/"
cp -a "$recipe/deployment" "$out/recipe/"
cp "$recipe/deployment/README.md" "$out/docs/DEPLOYMENT-GUARD.md"
cp "$recipe/../LICENSE" "$out/docs/deployment-guard-LICENSE.txt"
cp "$recipe/NOTICE.txt" "$out/docs/"
export GOTOOLCHAIN=local CGO_ENABLED=0 GOOS=linux GOARCH="$arch" GOAMD64=v1 GOARM64=v8.0 GOMAXPROCS=4
export GOPROXY=https://proxy.golang.org,direct
export GOSUMDB=sum.golang.org
go_version=$(jq -r .go "$recipe/versions.json")
[[ "$(go env GOVERSION)" == "go$go_version" ]]
go version | tee "$out/logs/go-version.txt"
for project in minio mc; do
  commit=$(jq -r ".$project.commit" "$recipe/versions.json")
  version=$(jq -r ".$project.version" "$recipe/versions.json")
  checksum=$(jq -r ".$project.archive_sha256" "$recipe/versions.json")
  curl -fL --retry 3 --connect-timeout 20 --max-time 300 \
    "https://codeload.github.com/minio/$project/tar.gz/$commit" -o "$out/upstream/$project.tar.gz"
  printf '%s  %s\n' "$checksum" "$out/upstream/$project.tar.gz" | sha256sum -c -
  mkdir "$out/src/$project"
  tar -xzf "$out/upstream/$project.tar.gz" --strip-components=1 -C "$out/src/$project"
  (
    cd "$out/src/$project"
    go mod download
    go mod verify
    go mod vendor
    package="github.com/minio/$project/cmd"
    release="DEVELOPMENT.${version//:/-}.sourcebuild"
    flags="-s -w -X $package.Version=$version -X $package.ReleaseTag=$release -X $package.CommitID=$commit -X $package.ShortCommitID=${commit:0:12} -X $package.CopyrightYear=2025"
    go build -mod=vendor -buildvcs=false -tags kqueue -trimpath -p 4 -ldflags "$flags" -o "$out/bin/$project" .
    go version -m "$out/bin/$project" | tee "$out/logs/$project-buildinfo.txt"
    grep -Fxq $'\tbuild\tGOARCH='"$arch" "$out/logs/$project-buildinfo.txt"
  ) 2>&1 | tee "$out/logs/$project-build.log"
done
python3 "$recipe/verify-upstream.py" "$out" | tee "$out/logs/upstream-source-integrity.json"
(cd "$recipe/deployment" && go build -trimpath -buildvcs=false -o "$out/bin/deployment-guard" .)
cp "$recipe/deployment/known-object-get.sh" "$out/bin/"
python3 "$recipe/collect-notices.py" "$out/src" "$out/licenses/go-dependencies"
cp -a "$(go env GOROOT)/src" "$out/toolchain/"
cp "$(go env GOROOT)/LICENSE" "$out/toolchain/"
cp "$recipe/versions.json" "$out/docs/versions.json"
distribution_source="https://github.com/${GITHUB_REPOSITORY:-oceanbase/docker-images}"
distribution_revision=${GITHUB_SHA:-$(git -C "$recipe" rev-parse HEAD)}
materials_url="$distribution_source/actions"
if [[ -n "${GITHUB_RUN_ID:-}" ]]; then
  materials_url="$distribution_source/actions/runs/$GITHUB_RUN_ID"
fi
printf 'Independent source build / 独立源码构建\nPackaging / 构建配方: %s/tree/%s/minio\nBuild and source artifacts / 构建及源码产物: %s\nArtifact / 产物名称: minio-test-packages-%s\nSource archive / 源码归档: source-and-build-materials-%s.tar.gz\nSources and checksums / 源码与校验值: versions.json\nThe source archive includes upstream sources, vendored dependencies, Go runtime source and build recipes.\n源码归档包含上游源码、vendored 依赖、Go runtime 源码及构建配方。\nThis is a test package; no image registry publication is performed.\n本包仅用于测试，未向镜像仓库发布。\n' \
  "$distribution_source" "$distribution_revision" "$materials_url" "$arch" "$arch" > "$out/docs/SOURCE-CODE.txt"
printf '\nMinIO and mc upstream source files are unchanged. No upstream patch is applied.\nMinIO 和 mc 上游源码文件未修改，不应用任何补丁。\nThe mc image also includes an independent Apache-2.0 deployment helper; see DEPLOYMENT-GUARD.md.\nmc 镜像另含独立的 Apache-2.0 部署辅助程序，说明见 DEPLOYMENT-GUARD.md。\n' >> "$out/docs/SOURCE-CODE.txt"
printf '%s\n' 'bin/' 'logs/' > "$out/recipe/.gitignore"
cat > "$out/.dockerignore" <<'EOF'
*
!Dockerfile
!bin/
!bin/**
!docs/
!docs/**
!licenses/
!licenses/**
!src/
!src/minio/
!src/minio/LICENSE
!src/minio/CREDITS
!src/minio/dockerscripts/
!src/minio/dockerscripts/docker-entrypoint.sh
!src/mc/
!src/mc/LICENSE
!src/mc/CREDITS
EOF
cp "$recipe/Dockerfile" "$out/Dockerfile"
args=(--platform "linux/$arch" --load --provenance=false
  --build-arg "BASE_IMAGE=$(jq -r .base_image "$recipe/versions.json")"
  --build-arg "DISTRIBUTION_SOURCE=$distribution_source"
  --build-arg "DISTRIBUTION_REVISION=$distribution_revision"
  --build-arg "MINIO_COMMIT=$(jq -r .minio.commit "$recipe/versions.json")"
  --build-arg "MINIO_VERSION=$(jq -r .minio.tag "$recipe/versions.json")"
  --build-arg "MC_COMMIT=$(jq -r .mc.commit "$recipe/versions.json")"
  --build-arg "MC_VERSION=$(jq -r .mc.tag "$recipe/versions.json")")
docker buildx build "${args[@]}" --target minio -t "$server" "$out" 2>&1 | tee "$out/logs/minio-image.log"
docker buildx build "${args[@]}" --target mc -t "$client" "$out" 2>&1 | tee "$out/logs/mc-image.log"
docker image inspect "$server" "$client" > "$out/logs/images.json"
(cd "$out" && sha256sum bin/minio bin/mc > logs/binary-sha256sums.txt)
