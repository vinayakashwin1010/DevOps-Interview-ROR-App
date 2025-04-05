resource "aws_s3_bucket" "main" {
  bucket = "${var.app_name}-${var.environment}-${random_id.bucket_suffix.hex}"
  acl    = "private"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  versioning {
    enabled = true
  }

  lifecycle_rule {
    id      = "cleanup-old-versions"
    enabled = true

    noncurrent_version_expiration {
      days = 30
    }
  }

  tags = {
    Name = "${var.app_name}-${var.environment}-bucket"
  }
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}