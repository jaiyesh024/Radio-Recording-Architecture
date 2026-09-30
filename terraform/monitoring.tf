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

          # Only select the PodMonitor created below for recorder metrics.
          podMonitorSelector = {
            matchLabels = {
              monitoring = "radio-recorder"
            }
          }
          # PodMonitor itself lives in the monitoring namespace.
          podMonitorNamespaceSelector = {
            matchNames = ["monitoring"]
          }

          storageSpec = {
            volumeClaimTemplate = {
              spec = {
                accessModes = ["ReadWriteOnce"]

                resources = {
                  requests = {
                    storage = "50Gi" # persistent storage to retain Prometheus data across restarts.
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

#Explicitly tells Prometheus Operator to scrape all recorder pods.
#The PodMonitor selects pods in the radio-recorders namespace using the "app = recorder" label and scrapes their named "metrics" port.

resource "kubernetes_manifest" "recorder_pod_monitor" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PodMonitor"

    metadata = {
      name      = "radio-recorder"
      namespace = "monitoring"

      labels = {
        monitoring = "radio-recorder"
      }
    }

    spec = {
      namespaceSelector = {
        matchNames = ["radio-recorders"]
      }

      selector = {
        matchLabels = {
          app = "recorder"
        }
      }

      podMetricsEndpoints = [
        {
          port     = "metrics"
          path     = "/metrics"
          interval = "30s"
        }
      ]
    }

  }

  depends_on = [helm_release.kube_prometheus_stack]
}

# Recording-gap and recorder health alerts.

resource "kubernetes_manifest" "recording_gap_alerts" {
  manifest = yamldecode(templatefile("${path.module}/../monitoring/alerts.yaml", {
    segment_duration_seconds = var.segment_duration_seconds
  }))

  depends_on = [helm_release.kube_prometheus_stack]
}
