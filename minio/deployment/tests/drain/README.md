# Graceful shutdown comparison (native AMD64 and ARM64)

Continue the distributed harness on its retained three-node test clusters and
105 objects from build 44492216536. Run only on authorized test machines; the
image binaries and independent helper are unchanged. No registry push is needed.

Place this directory's scripts under `/data/minio-no-patch`, and put the candidate
chart under `chart-drain`. Existing tools, kubeconfig, image identity files and
client Pod are reused. Never include credentials in evidence/source control.

`prepare-drain.sh` snapshots the 105 original hashes/PVC identities, runs Helm
lint and upgrades using `--reuse-values --set shutdownDrainSeconds=10 --set-string dnsCacheTTL=30s`, then
recreates the Pods (StatefulSet OnDelete) and verifies the original data. It
retains the existing Secret and volumes. Setting the value explicitly matters
when upgrading a Helm release that predates this setting.

Run `bash test-drain.sh STAGE ARCH` with ARCH=amd64 or arm64:

1. `monitor-start`, stop the third node runtime and its containers, then `offline`.
   The script creates two new objects (`during-outage-drain`, `outage-small-drain`)
   and verifies all 107 objects, preserving the previous 105.
2. Restart that node, then `recovered`, `cycles`, `samepod`, `monitor-stop`,
   `full-restart`. Cycles defaults to three rounds of all three Pods; ROUNDS can
   override it for a scoped diagnostic experiment.
3. Run the existing `../distributed/adapter-checks.sh` inside the client Pod.
   Save and compare evidence before cleanup. Data verification clears its local
   download directory before every full read and never rewrites/heals old data.

`EVIDENCE_DIR` selects a separate evidence directory (default evidence-drain).
Raw GET and explicit known-object adapter results stay separate. Genuine absence
must still return 404; do not reinterpret a successful script exit as proof of
zero false 404. Inspect all raw counts.

For diagnostics, execute `trace-loop.sh` inside the client Pod. It opens a separate
trace connection per server and reconnects after failure. Set /work/trace.stop
and terminate its trace children when done; traces are not guaranteed lossless
through server/process failures. Sanitize trace records before exporting them:
retain only time, server, path, status and duration, not request headers/queries.
`watch-drain.sh` runs on the cluster control machine and records Pod termination,
container status and business-Service EndpointSlice conditions. Stop with
`evidence-drain/watch.stop`; its maximum run is bounded.

These are controlled three-node HTTP tests. PreStop does not run on power loss,
SIGKILL or forced zero-grace deletion. A delay permits endpoint propagation and
peer recovery, but cannot itself prove metadata quorum correctness for all data.

## DNS refresh follow-up

Drain alone still returned false 404 on ARM. The final candidate also sets the
pinned upstream `MINIO_DNS_CACHE_TTL=1s` (default in Kubernetes: 30s). No upstream
source, executable or image changes are required. The original raw/trace evidence
is retained separately; this is not a change to HTTP response semantics.

For this follow-up, reuse the 107 existing objects and put the final chart under
`chart-dns`. Use `prepare-dns.sh` and `test-dns.sh` with the same stages above;
evidence goes to `evidence-dns`. `objects-dns.sh` adds two new outage objects,
resulting in 109, and `monitor-dns.sh` includes all earlier outage fixtures.
`reset-trace.sh` stops only mc trace processes in the dedicated client Pod before
starting a fresh per-node trace set. Never run it in an unrelated mc container.

Save each host's evidence-dns under `TASK/evidence/ARCH/evidence-dns`, then run
`python3.11 analyze-dns.py TASK` for evidence analysis. It checks all 107 original
hashes, 109 final objects, three unchanged PVCs, per-drive metadata counts,
nine recreations, process restart isolation, actual Helm settings and raw results.
The output field `false_404_acceptance` must be true for both architectures; do
not accept an absent architecture. Server trace summaries include only GetObject
for the known fixture names, excluding legitimate bucket-configuration 404s.
