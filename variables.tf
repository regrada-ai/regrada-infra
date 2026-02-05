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

# Cognito Configuration (using existing resources via data sources)
variable "cognito_client_id" {
  description = "AWS Cognito Client ID"
  type        = string
}

variable "cognito_client_secret" {
  description = "AWS Cognito Client Secret"
  type        = string
  sensitive   = true
}

variable "cognito_domain" {
  description = "AWS Cognito domain (e.g., your-domain.auth.us-east-1.amazoncognito.com)"
  type        = string
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

variable "cookie_domain" {
  description = "Cookie domain for cross-subdomain auth (e.g., .regrada.com)"
  type        = string
  default     = ""
}

# Tags
variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}

# Bastion Configuration
variable "bastion_enabled" {
  description = "Enable bastion host for SSH access to private resources"
  type        = bool
  default     = false
}

variable "bastion_public_key" {
  description = "SSH public key for bastion host"
  type        = string
  default     = ""
}
