# Self-hosted Prometheus + Grafana on-cluster via the well-known
# kube-prometheus-stack chart. Swap this for Amazon Managed Prometheus /
# Managed Grafana (aws_prometheus_workspace) if a fully managed option is
# preferred over operating Prometheus yourselves — the alert rules in
# ../monitoring/alerts.yaml are identical either way.

resource "helm_release" "kube_prometheus_stack" {
  name             = "monitoring"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true
  version          = "58.2.1"

  values = [
  yamlencode({
    grafana = {
      adminPassword = var.grafana_admin_password
    }

    prometheus = {
      prometheusSpec = {
        retention = "15d"

        storageSpec = {
          volumeClaimTemplate = {
            spec = {
              accessModes = ["ReadWriteOnce"]

              resources = {
                requests = {
                  storage = "50Gi"
                }
              }
            }
          }
        }

        ruleSelectorNilUsesHelmValues = false
      }
    }
  })
  ]
}

resource "kubernetes_manifest" "recording_gap_alerts" {
  manifest = yamldecode(templatefile("${path.module}/../monitoring/alerts.yaml", {
    segment_duration_seconds = var.segment_duration_seconds
  }))

  depends_on = [helm_release.kube_prometheus_stack]
}
