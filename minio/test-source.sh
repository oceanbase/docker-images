#!/usr/bin/env bash
# Run only on an authorized native test runner, after build.sh.
set -euo pipefail
out=$(cd "${1:?build output required}" && pwd)
export GOTOOLCHAIN=local CGO_ENABLED=0 GOMAXPROCS=4
cd "$out/src/minio"
saved=$(mktemp)
cp cmd/erasure-object.go "$saved"
restore() { cp "$saved" cmd/erasure-object.go; rm -f "$saved"; }
trap restore EXIT
commit=$(jq -r .minio.commit "$out/recipe/versions.json")
tar -xOzf "$out/upstream/minio.tar.gz" "minio-$commit/cmd/erasure-object.go" > cmd/erasure-object.go
set +e
go test -mod=vendor -p 4 -vet=off ./cmd -run '^TestLakehouseRejoinObjectQuorum/outage_write' -count=1 -v > "$out/logs/rejoin-unpatched.log" 2>&1
status=$?
set -e
cat "$out/logs/rejoin-unpatched.log"
test "$status" -ne 0
grep -Fq 'expected HTTP 503, got 404' "$out/logs/rejoin-unpatched.log"
cp "$saved" cmd/erasure-object.go
go test -mod=vendor -p 4 -vet=off ./cmd -run '^TestLakehouseRejoin' -count=1 -v 2>&1 | tee "$out/logs/rejoin-patched.log"
