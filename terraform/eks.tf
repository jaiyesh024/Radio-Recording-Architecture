# https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest#eks-managed-node-group

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.35"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access = true #this makes k8s endpoint publicly accessible.(should be avaoided in Prod or using a pvt endpoint)

  eks_managed_node_groups = {
    recorders = {
      min_size       = var.node_min_size
      max_size       = var.node_max_size
      desired_size   = var.node_desired_size
      instance_types = var.node_instance_types
      capacity_type  = "ON_DEMAND"

      labels = {
        workload = "recorder"
      }
    }
  }

  # Needed for IRSA (IAM Roles for Service Accounts) — lets the recorder pods
  # assume an IAM role scoped to S3 PutObject, without embedding credentials.
  enable_irsa = true

  tags = {
    Project     = "radio-recorder"
    Environment = var.environment
  }
}

resource "aws_ecr_repository" "recorder" {
  name                 = "radio-recorder"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Project     = "radio-recorder"
    Environment = var.environment
  }
}
