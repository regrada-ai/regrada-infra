# SPDX-License-Identifier: LicenseRef-Regrada-Proprietary
# vpc-endpoints.tf - VPC Endpoints for private subnet access to AWS services
#
# Replaces the NAT Gateway with VPC endpoints so that ECS Fargate tasks
# in private subnets can reach required AWS services without internet access.

# ============================================================================
# Security Group for Interface VPC Endpoints
# ============================================================================

resource "aws_security_group" "vpc_endpoints" {
  name_prefix = "${var.project_name}-${var.environment}-vpce-"
  description = "Allow HTTPS from VPC to interface VPC endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
    description = "HTTPS from VPC"
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-vpce-sg"
  })
}

# ============================================================================
# Gateway Endpoint - S3 (free, no hourly charge)
# ============================================================================

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-s3-endpoint"
  })
}

# ============================================================================
# Interface Endpoints
# ============================================================================

locals {
  interface_vpc_endpoints = {
    ecr-api        = "com.amazonaws.${var.aws_region}.ecr.api"
    ecr-dkr        = "com.amazonaws.${var.aws_region}.ecr.dkr"
    logs           = "com.amazonaws.${var.aws_region}.logs"
    secretsmanager = "com.amazonaws.${var.aws_region}.secretsmanager"
    sts            = "com.amazonaws.${var.aws_region}.sts"
  }
}

resource "aws_vpc_endpoint" "interface" {
  for_each = local.interface_vpc_endpoints

  vpc_id              = aws_vpc.main.id
  service_name        = each.value
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [aws_subnet.private.id]
  security_group_ids  = [aws_security_group.vpc_endpoints.id]

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-${each.key}-endpoint"
  })
}
