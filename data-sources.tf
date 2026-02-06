# SPDX-License-Identifier: LicenseRef-Regrada-Proprietary
# data-sources.tf - Data sources for existing AWS resources

# ============================================================================
# Existing Cognito User Pool
# ============================================================================

data "aws_cognito_user_pools" "existing" {
  name = "User pool - ypj8ol"
}

data "aws_cognito_user_pool" "main" {
  user_pool_id = "us-east-1_yjgQiprWD"
}

# Note: Client credentials must be passed as variables since they cannot be retrieved from data source
# See terraform.tfvars.example for required variables: cognito_client_id, cognito_client_secret

# ============================================================================
# Existing Route53 Hosted Zone
# ============================================================================

data "aws_route53_zone" "regrada" {
  zone_id      = "Z020639034BK26JZFNW6N"
  private_zone = false
}

# ============================================================================
# Existing SES Verified Domain
# ============================================================================

data "aws_ses_domain_identity" "regrada" {
  domain = "regrada.com"
}

# ============================================================================
# Existing S3 Bucket for User Assets
# ============================================================================

data "aws_s3_bucket" "user_assets" {
  bucket = "regrada-user-assets"
}

# ============================================================================
# Current AWS Account and Region
# ============================================================================

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}
