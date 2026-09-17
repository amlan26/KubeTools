# Promtail → Grafana Alloy migration

## Why

Promtail reached **end-of-life on March 2, 2026**. It had been in Long-Term
Support (LTS, bug/security fixes only) since February 2025, and after LTS
ended it receives no further updates of any kind. Grafana's official guidance
is to migrate to **Grafana Alloy**, which absorbed all future log-collection
development.

## What changed

- A new, separate Helm release (`alloy`, chart `grafana/alloy`) was installed
  to take over log collection.
- `promtail.enabled: false` was set in `loki/loki-values.yaml`, removing the
  Promtail DaemonSet that used to ship with the `loki-stack` chart.
- `fluent-bit`, `filebeat`, and `logstash` blocks (alternative shippers the
  `loki-stack` chart supports) were removed from `loki-values.yaml` — they
  were never enabled and added noise.

## How Alloy collects logs here

Unlike Promtail's single static config file, Alloy is built from composable
pipeline components. The config in `alloy/alloy-values.yaml` does the
following, per node:

1. `discovery.kubernetes` — discovers every pod running in the cluster via
   the Kubernetes API.
2. `discovery.relabel` — turns pod metadata into labels (`namespace`, `pod`,
   `container`, `node_name`, `job`) and computes the on-disk log path
   (`/var/log/pods/<ns>_<pod>_<uid>/<container>/*.log`).
3. `local.file_match` — resolves that path pattern to actual files present
   on the node Alloy is running on (this is what keeps it node-local, just
   like Promtail's DaemonSet was).
4. `loki.source.file` — tails those files.
5. `loki.process` (`stage.cri`) — parses the CRI log format (timestamp +
   stream + message) out of each line.
6. `loki.write` — pushes the result to `http://loki:3100/loki/api/v1/push`,
   the same endpoint Promtail was pushing to.

This mirrors Promtail's original DaemonSet + hostPath-tailing approach,
rather than switching to Alloy's alternative Kubernetes-API log-pull mode
(`loki.source.kubernetes`), which would require running Alloy as a
Deployment/StatefulSet instead of a DaemonSet to avoid every replica
re-scraping every pod's logs cluster-wide.

## Known non-issue: startup "timestamp too old" errors

On first install, Alloy has no position cursor yet (Promtail's old positions
file doesn't carry over), so it reads each log file **from the beginning**.
For long-lived files, that means replaying weeks-old log lines, which Loki
rejects with `400 Bad Request ... timestamp too old` because they fall
outside its acceptable ingestion window.

This is expected and harmless — Alloy is discarding backlog it doesn't need,
not dropping current data. The errors stop once each file's tail catches up
to the present. To skip this entirely on future installs/restarts, add
`ignore_older_than` to the `local.file_match` block in
`alloy/alloy-values.yaml`:

```river
local.file_match "pods" {
  path_targets      = discovery.relabel.pods.output
  ignore_older_than = "24h"
}
```

## Migration steps followed

1. Installed Alloy as a new release alongside the existing stack (Promtail
   still running, no gap in coverage):
   ```bash
   helm install alloy grafana/alloy -n monitoring -f alloy/alloy-values.yaml
   ```
2. Confirmed Alloy pods healthy and logs visible in Grafana Explore.
3. Disabled Promtail in the `loki-stack` release:
   ```bash
   helm upgrade loki grafana/loki-stack -n monitoring -f loki/loki-values.yaml
   ```
4. Confirmed Promtail pods were gone and logs kept flowing via Alloy only.

## References

- [Promtail EOL notice](https://grafana.com/docs/loki/latest/send-data/promtail/)
- [Migrate to Alloy](https://grafana.com/docs/alloy/latest/get-started/migrate/from-promtail/)
