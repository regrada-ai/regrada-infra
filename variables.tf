# SPDX-License-Identifier: LicenseRef-Regrada-Proprietary
# variables.tf - Input variables for Regrada infrastructure

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "regrada"
}

variable "environment" {
  description = "Environment name (e.g., production, staging)"
  type        = string
  default     = "production"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small"
}

# Cognito Configuration
variable "create_new_cognito" {
  description = "Whether to create a new Cognito User Pool or use existing"
  type        = bool
  default     = false
}

variable "existing_cognito_user_pool_name" {
  description = "Name of existing Cognito User Pool (if not creating new)"
  type        = string
  default     = ""
}

variable "cognito_callback_urls" {
  description = "List of allowed callback URLs for Cognito"
  type        = list(string)
  default     = ["http://localhost:3000/auth/callback"]
}

variable "cognito_logout_urls" {
  description = "List of allowed logout URLs for Cognito"
  type        = list(string)
  default     = ["http://localhost:3000"]
}

# Domain configuration (optional)
variable "domain_name" {
  description = "Domain name for the application (e.g., regrada.com)"
  type        = string
  default     = ""
}

variable "api_subdomain" {
  description = "Subdomain for API (e.g., api.regrada.com)"
  type        = string
  default     = "api"
}

variable "app_subdomain" {
  description = "Subdomain for app (e.g., app.regrada.com)"
  type        = string
  default     = "app"
}

# Backend environment variables
variable "cognito_user_pool_id" {
  description = "AWS Cognito User Pool ID"
  type        = string
}

variable "cognito_client_id" {
  description = "AWS Cognito Client ID"
  type        = string
}

variable "cognito_client_secret" {
  description = "AWS Cognito Client Secret"
  type        = string
  sensitive   = true
}

variable "s3_bucket" {
  description = "S3 bucket for file storage (optional)"
  type        = string
  default     = ""
}

variable "cloudfront_domain" {
  description = "CloudFront domain for CDN (optional)"
  type        = string
  default     = ""
}

variable "email_from_address" {
  description = "Email sender address (optional)"
  type        = string
  default     = ""
}

variable "email_from_name" {
  description = "Email sender name"
  type        = string
  default     = "Regrada"
}

# Database configuration
variable "postgres_user" {
  description = "PostgreSQL username"
  type        = string
  default     = "regrada"
}

# RDS Configuration
variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "Initial allocated storage for RDS (GB)"
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "Maximum allocated storage for RDS auto-scaling (GB)"
  type        = number
  default     = 100
}

# ElastiCache Configuration
variable "redis_node_type" {
  description = "ElastiCache Redis node type"
  type        = string
  default     = "cache.t4g.micro"
}

variable "postgres_db" {
  description = "PostgreSQL database name"
  type        = string
  default     = "regrada"
}

# Backend configuration
variable "backend_port" {
  description = "Backend API port"
  type        = number
  default     = 8080
}

variable "frontend_port" {
  description = "Frontend application port"
  type        = number
  default     = 3000
}

variable "gin_mode" {
  description = "Gin framework mode (debug or release)"
  type        = string
  default     = "release"
}

variable "secure_cookies" {
  description = "Enable secure cookies for production"
  type        = bool
  default     = true
}

# Tags
variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}
