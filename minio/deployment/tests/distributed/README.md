# Native distributed comparison harness

Run only on authorized disposable test machines. These scripts require an already
prepared three-node native-architecture Kubernetes cluster with `k3s`, Helm, both
images from run 44492216536 imported on every node, and a client node named
`x86-node0` or `arm-node0`. They do not provision or destroy machines.

This recorded harness uses `/data/minio-no-patch` as its root. Place `test.sh`,
`objects.sh`, `monitor.sh`, `chart/`, `tools/k3s`, `tools/helm`, `kubeconfig`,
`NOTICE.txt`, `expected-ARCH.txt` and an empty `evidence/` there. The expected file
contains the CI SHA256 lines for `/usr/bin/minio` and `/usr/bin/mc`. Keep kubeconfig
and credentials private; never add them to evidence or source control.

Run `bash test.sh STAGE ARCH` (ARCH is amd64 or arm64) in this order:

1. `install`, `baseline`: create 103 objects; record raw GET and explicit adapter
   results during two rounds of each Pod's recreation using standard probes only.
2. `enable-guard`, `monitor-start`: update the same release and PVCs, re-create
   Pods with independent admission sidecars, verify every original object.
3. Stop the third node's K3s runtime and its workload containers; keep the other
   two nodes, control plane and the SSH network alive. Run `offline` to verify
   existing data and write two new objects. Restart that same node; `recovered`.
4. `cycles`: three rounds of each Pod's recreation. `samepod`: SIGKILL only the
   MinIO process in one Pod while keeping its guard process alive.
5. `monitor-stop`, `full-restart`: stop all three MinIO Pods, retain PVCs, restart,
   read every object into a freshly cleared directory and compare SHA256.
6. Execute `adapter-checks.sh` with Bash inside the `mc` client Pod to verify
   genuine 404, credential 403, checksum rejection and bounded retry exhaustion.

The client Pod holds the independent authoritative expected hashes; this does not
mean arbitrary S3/database clients have such hashes or use this adapter. Raw GET
and adapter results are intentionally separate. Baseline failures are recorded,
not suppressed; inspect logs even when a later full read succeeds. Compare PVC
UIDs, original object hashes, per-drive metadata counts and image/binary identity.
Never treat Ready, retries succeeding, or a completed shell script as evidence of
zero false 404. Runtime/node failure is not physical-host failure certification.

After saving each remote evidence directory under `TASK/evidence/ARCH/evidence`,
run `python3 summarize-evidence.py TASK` for evidence analysis. It checks data and
PVC invariants and produces separate raw/adapter counts; a successful analysis
exit is not false-404 acceptance. Review the HTTP counts explicitly.
