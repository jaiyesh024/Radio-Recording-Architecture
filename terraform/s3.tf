# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket

resource "aws_s3_bucket" "recordings" {
  bucket = var.recordings_bucket_name

  tags = {
    Project     = "radio-recorder"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "recordings" {                  ##supporting s3 versioning 
  bucket = aws_s3_bucket.recordings.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "recordings" {        ##serverside encryption.
  bucket = aws_s3_bucket.recordings.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "recordings" {
  bucket = aws_s3_bucket.recordings.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "recordings" {
  bucket = aws_s3_bucket.recordings.id

  rule {
    id     = "tier-down-old-segments"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    # Adjust or remove for compliance/retention requirements — this is a
    # sensible default, not a mandated retention policy.
    expiration {
      days = 365
    }

    noncurrent_version_expiration {             #lifecycling handling/removal for older versions
      noncurrent_days = 30
    } 
  }
}
