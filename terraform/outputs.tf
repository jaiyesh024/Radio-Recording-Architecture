output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
}

output "recordings_bucket" {
  description = "S3 bucket holding recorded audio segments"
  value       = aws_s3_bucket.recordings.bucket
}

output "recorder_ecr_repository_url" {
  description = "Push the recorder binary's container image here"
  value       = aws_ecr_repository.recorder.repository_url
}

output "configure_kubectl" {
  description = "Command to point kubectl at this cluster"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "station_count" {
  description = "Number of stations currently configured to record"
  value       = length(var.stations)
}
