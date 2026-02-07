# SPDX-License-Identifier: LicenseRef-Regrada-Proprietary
# outputs.tf - Output values from Terraform

# ============================================================================
# Network Outputs
# ============================================================================

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

# ============================================================================
# Domain Outputs
# ============================================================================

output "website_url" {
  description = "Website URL"
  value       = "https://www.regrada.com"
}

output "api_url" {
  description = "API URL"
  value       = "https://api.regrada.com"
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.main.dns_name
}

# ============================================================================
# ECS Outputs
# ============================================================================

output "ecs_cluster_name" {
  description = "ECS Cluster name"
  value       = aws_ecs_cluster.main.name
}

output "backend_service_name" {
  description = "Backend ECS service name"
  value       = aws_ecs_service.backend.name
}

output "frontend_service_name" {
  description = "Frontend ECS service name"
  value       = aws_ecs_service.frontend.name
}

# ============================================================================
# ECR Outputs
# ============================================================================

output "backend_ecr_repository_url" {
  description = "Backend ECR repository URL"
  value       = aws_ecr_repository.backend.repository_url
}

output "frontend_ecr_repository_url" {
  description = "Frontend ECR repository URL"
  value       = aws_ecr_repository.frontend.repository_url
}

# ============================================================================
# Database Outputs
# ============================================================================

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = aws_db_instance.postgres.endpoint
  sensitive   = true
}

output "rds_password_secret_arn" {
  description = "ARN of secret containing RDS password"
  value       = aws_secretsmanager_secret.rds_password.arn
  sensitive   = true
}

# ============================================================================
# ElastiCache Outputs
# ============================================================================

output "redis_endpoint" {
  description = "ElastiCache Redis primary endpoint"
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
  sensitive   = true
}

output "redis_port" {
  description = "ElastiCache Redis port"
  value       = aws_elasticache_replication_group.redis.port
}

# ============================================================================
# S3 Outputs
# ============================================================================

output "user_assets_bucket" {
  description = "S3 bucket for user assets"
  value       = data.aws_s3_bucket.user_assets.id
}

# ============================================================================
# ACM Certificate
# ============================================================================

output "acm_certificate_arn" {
  description = "ACM certificate ARN"
  value       = aws_acm_certificate.main.arn
}

# ============================================================================
# Bastion Outputs
# ============================================================================

output "bastion_public_ip" {
  description = "Static public IP address of the bastion host (Elastic IP)"
  value       = var.bastion_enabled ? aws_eip.bastion[0].public_ip : null
}

output "bastion_ssh_command" {
  description = "SSH command to connect to the bastion host"
  value       = var.bastion_enabled ? "ssh -i <your-key.pem> ec2-user@${aws_eip.bastion[0].public_ip}" : null
}

# ============================================================================
# NAT Instance Outputs
# ============================================================================

output "nat_instance_private_ip" {
  description = "Private IP of the NAT instance (for SSH from bastion)"
  value       = aws_instance.nat.private_ip
}

output "nat_ssh_command_from_bastion" {
  description = "SSH command to connect to NAT instance from bastion"
  value       = "ssh ec2-user@${aws_instance.nat.private_ip}"
}
