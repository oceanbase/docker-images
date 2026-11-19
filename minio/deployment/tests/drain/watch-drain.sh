#!/bin/bash
set -eu
R=/data/minio-no-patch; export KUBECONFIG=$R/kubeconfig
for ((i=0;i<600;i++)); do
 test ! -f "$R/evidence-drain/watch.stop" || break
 date -u +%FT%T.%NZ
 "$R/tools/k3s" kubectl -n minio-unpatched get pods -l app.kubernetes.io/component=minio -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.metadata.uid}{" deleting="}{.metadata.deletionTimestamp}{" "}{range .status.containerStatuses[*]}{.name}{" ready="}{.ready}{" running="}{.state.running.startedAt}{" finished="}{.state.terminated.finishedAt}{";"}{end}{"\n"}{end}'
 "$R/tools/k3s" kubectl -n minio-unpatched get endpointslices -l kubernetes.io/service-name=qa-minio -o jsonpath='{range .items[*].endpoints[*]}{.targetRef.name}{" "}{.conditions}{"\n"}{end}'
 sleep 1
done
