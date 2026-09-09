#!/usr/bin/env bash
# ==============================================================================
#  install.sh — Bootstrap the Prometheus + Grafana + Loki monitoring stack
#  Usage: ./scripts/install.sh
# ==============================================================================
set -euo pipefail

NAMESPACE="monitoring"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "▶ Creating namespace: ${NAMESPACE}"
kubectl create ns "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

echo "▶ Adding Helm repositories"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add stable https://charts.helm.sh/stable
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

echo "▶ Installing kube-prometheus-stack (Prometheus + Grafana + Alertmanager)"
helm install kind-prometheus prometheus-community/kube-prometheus-stack \
  --namespace "${NAMESPACE}" \
  --set prometheus.service.nodePort=31111 \
  --set prometheus.service.type=NodePort \
  --set grafana.service.nodePort=31112 \
  --set grafana.service.type=NodePort \
  --set alertmanager.service.nodePort=31113 \
  --set alertmanager.service.type=NodePort \
  --set prometheus-node-exporter.service.nodePort=31114 \
  --set prometheus-node-exporter.service.type=NodePort \
  -f "${ROOT_DIR}/prometheus/prometheus-values.yaml"

echo "▶ Installing Loki + Promtail (log aggregation)"
helm upgrade --install loki -f "${ROOT_DIR}/loki/loki-values.yaml" \
  -n "${NAMESPACE}" --create-namespace grafana/loki-stack

echo "✔ Stack installed. Run 'kubectl get pods -n ${NAMESPACE}' to check status."