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

# Note: Client secret must be passed as variable since it cannot be retrieved from data source
# Cognito Client ID: 3676h3h2n7qv227s40mufjdipv
# Cognito Client Secret: nsjbnecnobpccde321skm9tqbfmiu6rra831pivrsh9t1tlev1p

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
