# Architecture notes

All components run in the `monitoring` namespace unless noted.

## Components

| Component | Chart | Deployment kind | Role |
|---|---|---|---|
| Prometheus | `prometheus-community/kube-prometheus-stack` | StatefulSet (1 replica) | Stores metrics, evaluates alert rules |
| Prometheus Operator | (bundled in kube-prometheus-stack) | Deployment | Turns `ServiceMonitor`/`PodMonitor`/`PrometheusRule` CRDs into Prometheus config |
| Alertmanager | (bundled) | StatefulSet | Routes/dedupes firing alerts |
| node-exporter | (bundled) | DaemonSet | Host-level metrics (CPU, memory, disk, network) per node |
| kube-state-metrics | (bundled) | Deployment | Metrics about Kubernetes objects themselves (pod status, deployment replicas, etc.) |
| Grafana | (bundled) | Deployment | Dashboards, Explore, alerting UI |
| Loki | `grafana/loki-stack` | StatefulSet (1 replica, single-binary mode) | Log storage & query engine |
| Alloy | `grafana/alloy` | DaemonSet | Tails container logs per node, ships to Loki |
| Tempo | `grafana/tempo` | StatefulSet (1 replica) | Trace storage & query engine |

## Ports

| Service | Port | Protocol |
|---|---|---|
| Prometheus | 9090 | HTTP |
| Loki | 3100 | HTTP (push + query API) |
| Tempo | 3100 | HTTP (query API) |
| Tempo OTLP | 4317 | gRPC |
| Tempo OTLP | 4318 | HTTP |
| Alloy UI | 12345 | HTTP (debugging only, not for ingestion) |

## Why single-replica StatefulSets

Loki and Tempo are both deployed here in **single-binary** mode (one pod
each), which is appropriate for a single small/dev cluster. This keeps
operational complexity low but means:

- No high availability — if the `loki-0` or `tempo-0` pod goes down,
  ingestion and queries pause until it's rescheduled.
- Storage is a single PVC per component, so throughput is bounded by that
  one volume.

For a production-scale cluster, both Loki and Tempo support distributed
"microservices" deployment modes (separate ingester/querier/compactor
components with object storage like S3/GCS behind them) — worth revisiting
if log/trace volume grows significantly.

## Namespacing of collected data

Alloy and node-exporter collect from **every namespace** in the cluster by
default (no namespace filter is applied in `discovery.kubernetes`/
`discovery.relabel`). If you need to scope collection to specific
namespaces later, add a `rule` block in `discovery.relabel` in
`alloy/alloy-values.yaml` that drops targets outside the namespaces you
want.
