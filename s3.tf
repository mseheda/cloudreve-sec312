data "aws_caller_identity" "current" {}

locals {
  customer_bucket_name = "${var.name_prefix}-customer-data-${data.aws_caller_identity.current.account_id}"
  backup_bucket_name   = "${var.name_prefix}-customer-backups-${data.aws_caller_identity.current.account_id}"
}

############################################
# Customer data bucket
############################################

resource "aws_s3_bucket" "customer_data" {
  bucket = local.customer_bucket_name

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-s3-customer-data"
  })
}

resource "aws_s3_bucket_ownership_controls" "customer_data" {
  bucket = aws_s3_bucket.customer_data.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "customer_data" {
  bucket = aws_s3_bucket.customer_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "customer_data" {
  bucket = aws_s3_bucket.customer_data.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "customer_data" {
  bucket = aws_s3_bucket.customer_data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

############################################
# Backup bucket
############################################

resource "aws_s3_bucket" "customer_backups" {
  bucket = local.backup_bucket_name

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-s3-customer-backups"
  })
}

resource "aws_s3_bucket_ownership_controls" "customer_backups" {
  bucket = aws_s3_bucket.customer_backups.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "customer_backups" {
  bucket = aws_s3_bucket.customer_backups.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "customer_backups" {
  bucket = aws_s3_bucket.customer_backups.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "customer_backups" {
  bucket = aws_s3_bucket.customer_backups.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Lifecycle for backups: move to Glacier, then expire
resource "aws_s3_bucket_lifecycle_configuration" "customer_backups" {
  bucket = aws_s3_bucket.customer_backups.id

  rule {
    id     = "backup-lifecycle"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = 365
    }
  }
}

############################################
# Replication: customer_data -> customer_backups
############################################

resource "aws_iam_role" "s3_replication_role" {
  name = "${var.name_prefix}-s3-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "s3.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })

  tags = merge(var.tags, { Name = "${var.name_prefix}-iam-s3-replication-role" })
}

resource "aws_iam_role_policy" "s3_replication_policy" {
  name = "${var.name_prefix}-s3-replication-policy"
  role = aws_iam_role.s3_replication_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # Read from source
      {
        Effect = "Allow",
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket"
        ],
        Resource = [
          aws_s3_bucket.customer_data.arn
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging",
          "s3:GetObjectRetention",
          "s3:GetObjectLegalHold"
        ],
        Resource = [
          "${aws_s3_bucket.customer_data.arn}/*"
        ]
      },

      # Replicate into destination
      {
        Effect = "Allow",
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags",
          "s3:ObjectOwnerOverrideToBucketOwner"
        ],
        Resource = [
          "${aws_s3_bucket.customer_backups.arn}/*"
        ]
      }
    ]
  })
}

# Destination bucket policy to allow replication writes
resource "aws_s3_bucket_policy" "customer_backups" {
  bucket = aws_s3_bucket.customer_backups.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowReplicationFromSourceRole",
        Effect = "Allow",
        Principal = {
          AWS = aws_iam_role.s3_replication_role.arn
        },
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags",
          "s3:ObjectOwnerOverrideToBucketOwner"
        ],
        Resource = "${aws_s3_bucket.customer_backups.arn}/*"
      }
    ]
  })
}

resource "aws_s3_bucket_replication_configuration" "customer_data_to_backups" {
  bucket = aws_s3_bucket.customer_data.id
  role   = aws_iam_role.s3_replication_role.arn

  rule {
    id     = "replicate-all"
    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.customer_backups.arn
      storage_class = "STANDARD"
    }
  }

  depends_on = [
    aws_s3_bucket_versioning.customer_data,
    aws_s3_bucket_versioning.customer_backups
  ]
}

############################################
# Outputs
############################################

output "customer_data_bucket_name" {
  value = aws_s3_bucket.customer_data.bucket
}

output "customer_backups_bucket_name" {
  value = aws_s3_bucket.customer_backups.bucket
}
