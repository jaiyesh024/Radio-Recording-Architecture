variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-2"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "radio-recorder"
}

variable "environment" {
  description = "Env"
  type        = string
  default     = "dev"
}

variable "recordings_bucket_name" {
  description = "S3 bucket name for recorded audio segments."
  type        = string
  default     = "radio-recordings-audio"
}

variable "node_instance_types" {
  description = "EC2 instance types for the EKS managed node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_min_size" {
  description = "Minimum node count (CA)"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum node count (CA)"
  type        = number
  default     = 20
}

variable "node_desired_size" {
  description = "Initial desired node count"
  type        = number
  default     = 3
}

variable "recorder_image" {
  description = "Container image for the recorder binary wrapper"
  type        = string
  default     = "internal/radio-recorder:latest"
}

variable "segment_duration_seconds" {
  description = "Length of each recorded audio segment(in secs) set to 5mins"
  type        = number
  default     = 300
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
}

# The station registry. In production this would more naturally be a database
# table with Terraform reading it via a data source, or a generated .tfvars file
# from a CI step that syncs from that table — kept as a plain variable here to
# keep the reference implementation self-contained and easy to review.
#
# Scaling from 20 to 100 stations = adding entries here and running
# `terraform apply`. No other change required.
variable "stations" {
  description = "Map of station_id => station config to record"
  type = map(object({
    url = string
  }))

  default = {
    "001" = { url = "https://example-radio-stream.com/station-001" }
    "002" = { url = "https://example-radio-stream.com/station-002" }
  }
}
