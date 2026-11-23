#!/usr/bin/env bash
set -euo pipefail
arch=${1:?architecture required}
work=${2:?new evidence directory required}
server=${3:?server image required}
client=${4:?client image required}
recipe=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
case "$arch/$(uname -m)" in amd64/x86_64|arm64/aarch64) ;; *) echo 'Runtime tests require the native target architecture' >&2; exit 1;; esac
test ! -e "$work"
mkdir -p "$work/objects"
work=$(cd "$work" && pwd)
chmod 0777 "$work/objects"
name="minio-test-$(cat /proc/sys/kernel/random/uuid)"
volume="$name-data"
username="qa$(cat /proc/sys/kernel/random/uuid | tr -d -)"
password="$(cat /proc/sys/kernel/random/uuid)$(cat /proc/sys/kernel/random/uuid)"
umask 077
printf 'MINIO_ROOT_USER=%s\nMINIO_ROOT_PASSWORD=%s\nMINIO_UPDATE=off\n' "$username" "$password" > "$work/server.env"
printf 'MC_HOST_qa=http://%s:%s@127.0.0.1:9000\nMC_UPDATE=off\n' "$username" "$password" > "$work/client.env"
printf 'MC_HOST_qa=http://%s:wrong-password@127.0.0.1:9000\nMC_UPDATE=off\n' "$username" > "$work/bad.env"
stage=identity
cleanup() {
  rc=$?
  trap - EXIT
  if docker inspect "$name" > /dev/null 2>&1; then
    docker logs "$name" 2>&1 | sed "s/$password/[REDACTED]/g;s/$username/[USER]/g" > "$work/server.log" || true
    docker rm -f "$name" > /dev/null || rc=1
  fi
  while read -r id; do
    [[ -z "$id" ]] || docker rm -f "$id" > /dev/null || rc=1
  done < <(docker ps -aq --filter "label=qa.minio.run=$name")
  if docker volume inspect "$volume" > /dev/null 2>&1; then
    docker volume rm "$volume" > /dev/null || rc=1
  fi
  rm -f "$work"/*.env "$work/objects/"*
  rmdir "$work/objects"
  printf '{"architecture":"%s","native":true,"exit_code":%s,"last_stage":"%s"}\n' "$arch" "$rc" "$stage" > "$work/result.json"
  cat "$work/result.json"
  exit "$rc"
}
trap cleanup EXIT
pass() { echo "PASS $stage" | tee -a "$work/checks.log"; }
mc() {
  timeout 120 docker run --rm --label "qa.minio.run=$name" --network "container:$name" \
    --user 10001:10001 --read-only --tmpfs /tmp:rw,nosuid,size=64m,mode=1777 \
    --env-file "$work/client.env" -v "$work/objects:/work" "$client" "$@"
}
health() {
  for ((i=0; i<60; i++)); do
    if docker exec "$name" curl -fsS http://127.0.0.1:9000/minio/health/ready > /dev/null 2>&1; then return; fi
    sleep 2
  done
  return 1
}
start() {
  docker run -d --name "$name" --label "qa.minio.run=$name" --network none \
    --user 10001:10001 --read-only --tmpfs /tmp:rw,nosuid,size=64m,mode=1777 \
    --cpus 2 --memory 2g --env-file "$work/server.env" -v "$volume:/data" \
    "$server" server /data --console-address :9001 > /dev/null
  health
}
readback() {
  for key in empty.bin small.bin large.bin; do
    mc cp "qa/runtime-check/$key" "/work/download-$key" > /dev/null
    cmp "$work/objects/$key" "$work/objects/download-$key"
  done
  pass
}
for component in minio mc; do
  image=$server
  if [[ "$component" == mc ]]; then image=$client; fi
  [[ "$(docker image inspect --format '{{.Architecture}}/{{.Os}}' "$image")" == "$arch/linux" ]]
  docker run --rm --network none --entrypoint sh "$image" -ec \
    'test -s /licenses/mc/LICENSE; test -s /licenses/mc/CREDITS; test -s /usr/share/doc/oceanbase-minio/NOTICE.txt; test -s /usr/share/doc/oceanbase-minio/SOURCE-CODE.txt'
  docker run --rm --network none --entrypoint cat "$image" /usr/share/doc/oceanbase-minio/NOTICE.txt > "$work/$component-NOTICE.txt"
  cmp "$recipe/NOTICE.txt" "$work/$component-NOTICE.txt"
  sha256sum "$work/$component-NOTICE.txt" >> "$work/notice-sha256sums.txt"
  docker run --rm --network none --entrypoint cat "$image" /usr/share/doc/oceanbase-minio/SOURCE-CODE.txt > "$work/$component-SOURCE-CODE.txt"
  grep -Fq "source-and-build-materials-$arch.tar.gz" "$work/$component-SOURCE-CODE.txt"
  if [[ -n "${GITHUB_RUN_ID:-}" ]]; then
    grep -Fxq "Build and source artifacts / 构建及源码产物: https://github.com/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID" "$work/$component-SOURCE-CODE.txt"
  fi
  docker run --rm --network none --entrypoint sh "$image" -ec \
    'test -n "$(find /licenses/distribution/go-dependencies -type f -print -quit)"'
done
docker image inspect "$server" "$client" > "$work/images.json"
docker run --rm --network none "$server" --version > "$work/minio-version.txt"
docker run --rm --network none "$client" --version > "$work/mc-version.txt"
grep -Fq "$(jq -r .minio.commit "$recipe/versions.json")" "$work/minio-version.txt"
grep -Fq "$(jq -r .mc.commit "$recipe/versions.json")" "$work/mc-version.txt"
grep -Fq DEVELOPMENT. "$work/minio-version.txt"
grep -Fq DEVELOPMENT. "$work/mc-version.txt"
server_mc=$(docker run --rm --network none --entrypoint sha256sum "$server" /usr/bin/mc)
client_mc=$(docker run --rm --network none --entrypoint sha256sum "$client" /usr/bin/mc)
test "$server_mc" = "$client_mc"
docker run --rm --network none --entrypoint sh "$server" -ec 'test -s /licenses/minio/LICENSE; test -s /licenses/minio/CREDITS'
pass
stage=fixtures
: > "$work/objects/empty.bin"
dd if=/dev/urandom of="$work/objects/small.bin" bs=1048576 count=1 status=none
dd if=/dev/urandom of="$work/objects/large.bin" bs=1048576 count=80 status=none
chmod 0644 "$work/objects/"*.bin
docker volume create --label "qa.minio.run=$name" "$volume" > /dev/null
docker run --rm --network none --entrypoint sh -v "$volume:/data" "$server" -c 'chmod 0777 /data'
stage=nonroot_readonly_start
start
test "$(docker exec "$name" id -u)" = 10001
test "$(docker exec "$name" curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:9001/)" = 200
pass
stage=bucket_idempotence
mc mb --ignore-existing qa/runtime-check > /dev/null
mc mb --ignore-existing qa/runtime-check > /dev/null
pass
stage=upload_download
for key in empty.bin small.bin large.bin; do mc cp "/work/$key" "qa/runtime-check/$key" > /dev/null; done
readback
stage=list_stat_copy_delete
mc ls --json qa/runtime-check > "$work/list.jsonl"
test "$(wc -l < "$work/list.jsonl")" -eq 3
mc stat --json qa/runtime-check/large.bin > "$work/stat.json"
mc cp qa/runtime-check/small.bin qa/runtime-check/copied.bin > /dev/null
mc rm qa/runtime-check/copied.bin > /dev/null
if mc stat qa/runtime-check/copied.bin > /dev/null 2>&1; then exit 1; fi
pass
stage=authentication
if timeout 60 docker run --rm --label "qa.minio.run=$name" --network "container:$name" --env-file "$work/bad.env" "$client" ls qa/runtime-check > /dev/null 2>&1; then exit 1; fi
test "$(docker exec "$name" curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:9000/runtime-check/small.bin)" = 403
pass
stage=restart_data_retained
docker restart "$name" > /dev/null
health
readback
stage=kill_start_data_retained
docker kill --signal KILL "$name" > /dev/null
docker start "$name" > /dev/null
health
readback
stage=recreate_data_retained
docker rm -f "$name" > /dev/null
start
readback
stage=bucket_cleanup
mc rm --recursive --force qa/runtime-check > /dev/null
mc rb qa/runtime-check > /dev/null
pass
