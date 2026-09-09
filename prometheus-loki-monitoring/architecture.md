# 🏗️ Architecture

This stack is composed of two independent Helm releases installed into the
same `monitoring` namespace:

1. **`kind-prometheus`** — from chart `prometheus-community/kube-prometheus-stack`
   Bundles: Prometheus Operator, Prometheus, Alertmanager, Grafana, Node
   Exporter, kube-state-metrics.

2. **`loki`** — from chart `grafana/loki-stack`
   Bundles: Loki (log store), Promtail (log shipper/DaemonSet).

## Component Responsibilities

| Component | Role |
|---|---|
| **Prometheus** | Pulls (scrapes) time-series metrics from instrumented pods and exporters on a schedule. |
| **Node Exporter** | Exposes host-level OS metrics (CPU, memory, disk, network) per node. |
| **kube-state-metrics** | Exposes Kubernetes object state (deployments, pods, nodes) as metrics. |
| **Alertmanager** | Deduplicates, groups, and routes alerts fired by Prometheus rules. |
| **Grafana** | Visualization layer; queries both Prometheus (PromQL) and Loki (LogQL). |
| **Promtail** | DaemonSet agent that tails `/var/log/containers/*.log` on every node and pushes to Loki. |
| **Loki** | Log aggregation system — indexes only metadata (labels), keeping storage costs low. |

## Data Flow Summary

```
 ┌────────────┐        scrape /metrics        ┌────────────┐
 │  App Pods  │ ─────────────────────────────▶ │ Prometheus │
 └────────────┘                                └─────┬──────┘
       │ stdout/stderr logs                          │ alerts
       ▼                                              ▼
 ┌────────────┐        push logs API          ┌──────────────┐
 │  Promtail  │ ─────────────────────────────▶ │ Alertmanager │
 └─────┬──────┘                                └──────────────┘
       ▼
 ┌────────────┐                                ┌────────────┐
 │    Loki    │◀───────────── query (LogQL) ── │  Grafana   │ ──▶ query (PromQL) ──▶ Prometheus
 └────────────┘                                └────────────┘
```

## Ports Reference

| Service | Internal Port | Exposed NodePort |
|---|---|---|
| Prometheus | 9090 | 31111 |
| Grafana | 3000 | 31112 |
| Alertmanager | 9093 | 31113 |
| Node Exporter | 9100 | 31114 |
| Loki | 3100 | *(ClusterIP only, add Ingress if needed)* |