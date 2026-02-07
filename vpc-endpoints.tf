# SPDX-License-Identifier: LicenseRef-Regrada-Proprietary
# vpc-endpoints.tf - S3 Gateway VPC Endpoint (free)
#
# Keeps S3 traffic off the NAT instance to reduce data processing costs.

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-s3-endpoint"
  })
}
