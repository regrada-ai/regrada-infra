# SPDX-License-Identifier: LicenseRef-Regrada-Proprietary
# s3-public.tf - S3 bucket for public assets served via CloudFront

# ============================================================================
# S3 Bucket for Public Assets
# ============================================================================

resource "aws_s3_bucket" "public_assets" {
  bucket = "regrada-public"

  tags = local.common_tags
}

resource "aws_s3_bucket_versioning" "public_assets" {
  bucket = aws_s3_bucket.public_assets.id

  versioning_configuration {
    status = "Enabled"
  }
}

# ============================================================================
# CloudFront Origin Access Control
# ============================================================================

resource "aws_cloudfront_origin_access_control" "public_assets" {
  name                              = "regrada-public-oac"
  description                       = "OAC for regrada-public S3 bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# ============================================================================
# S3 Bucket Policy - Allow CloudFront Access
# ============================================================================

resource "aws_s3_bucket_policy" "public_assets" {
  bucket = aws_s3_bucket.public_assets.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.public_assets.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = "arn:aws:cloudfront::${data.aws_caller_identity.current.account_id}:distribution/E1T7A9H13NLC2T"
          }
        }
      }
    ]
  })
}

# ============================================================================
# Block Public Access (access is via CloudFront only)
# ============================================================================

resource "aws_s3_bucket_public_access_block" "public_assets" {
  bucket = aws_s3_bucket.public_assets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ============================================================================
# CORS Configuration (if needed for web assets)
# ============================================================================

resource "aws_s3_bucket_cors_configuration" "public_assets" {
  bucket = aws_s3_bucket.public_assets.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["https://regrada.com", "https://www.regrada.com", "https://api.regrada.com"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3600
  }
}

# ============================================================================
# Outputs
# ============================================================================

output "public_assets_bucket_name" {
  description = "Name of the public assets S3 bucket"
  value       = aws_s3_bucket.public_assets.id
}

output "public_assets_bucket_arn" {
  description = "ARN of the public assets S3 bucket"
  value       = aws_s3_bucket.public_assets.arn
}

output "public_assets_bucket_regional_domain" {
  description = "Regional domain name for CloudFront origin"
  value       = aws_s3_bucket.public_assets.bucket_regional_domain_name
}

output "cloudfront_oac_id" {
  description = "CloudFront Origin Access Control ID to use when adding origin"
  value       = aws_cloudfront_origin_access_control.public_assets.id
}
