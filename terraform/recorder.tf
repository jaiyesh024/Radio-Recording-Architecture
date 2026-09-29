# The heart of "easy to scale 20 -> 100 stations with minimal effort":
# one Deployment per entry in var.stations. Adding stations is adding entries
# to that map (terraform.tfvars) and running `terraform apply` — no other
# change needed anywhere in this file.

# Terraform sending "k8s deployment" creation req to EKS API server.

resource "kubernetes_deployment" "recorder" {
  for_each = var.stations

  metadata {
    name      = "recorder-${each.key}"
    namespace = kubernetes_namespace.radio_recorders.metadata[0].name
    labels = {
      app        = "recorder"
      station_id = each.key
    }
  }

# From abv : Terraform will create one independant deployment per station.
# eg:
#   Deployment/recorder-001
#   Deployment/recorder-002
#   Deployment/recorder-003

  spec {
    replicas = 1

    selector {
      match_labels = {
        station_id = each.key
      }
    }

    template {
      metadata {
        labels = {
          app        = "recorder"
          station_id = each.key
        }
        annotations = {
          "prometheus.io/scrape" = "true"
          "prometheus.io/port"   = "9090"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.recorder.metadata[0].name
        restart_policy       = "Always"

        container {
          name  = "recorder"
          image = var.recorder_image

          env {
            name  = "STATION_ID"
            value = each.key
          }
          env {
            name  = "STATION_URL"
            value = each.value.url
          }
          env {
            name  = "OUTPUT_PREFIX"
            value = "s3://${aws_s3_bucket.recordings.bucket}/${each.key}"
          }
          env {
            name  = "SEGMENT_DURATION_SECONDS"
            value = tostring(var.segment_duration_seconds)
          }
          env {
            name  = "AWS_REGION"
            value = var.aws_region
          }

          port {
            container_port = 9090
            name           = "metrics"
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "250m"
              memory = "256Mi"
            }
          }

          liveness_probe {  
            exec {
              command = ["/bin/sh", "-c", "pgrep recorder"]
            }
            initial_delay_seconds = 10
            period_seconds        = 15
          }

          volume_mount {
            name       = "segment-buffer"
            mount_path = "/var/recorder/buffer"
          }
        }

        volume {              
          name = "segment-buffer"                   ##provides temp local buffering for segment awaiting upload.
          empty_dir {}
        }
      }
    }
  }
}
