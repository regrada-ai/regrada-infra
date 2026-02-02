# elasticache.tf - ElastiCache Redis cluster

# ============================================================================
# ElastiCache Subnet Group
# ============================================================================

resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.project_name}-${var.environment}-redis-subnet"
  subnet_ids = [aws_subnet.private.id, aws_subnet.private_2.id]

  tags = local.common_tags
}

# ============================================================================
# ElastiCache Security Group
# ============================================================================

resource "aws_security_group" "elasticache" {
  name_prefix = "${var.project_name}-${var.environment}-elasticache-sg"
  description = "Security group for ElastiCache Redis"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.backend.id]
    description     = "Redis from backend"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-elasticache-sg"
  })
}

# ============================================================================
# ElastiCache Parameter Group
# ============================================================================

resource "aws_elasticache_parameter_group" "redis" {
  name   = "${var.project_name}-${var.environment}-redis-params"
  family = "redis7"

  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }

  tags = local.common_tags
}

# ============================================================================
# ElastiCache Redis Cluster
# ============================================================================

resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "${var.project_name}-${var.environment}-redis"
  engine               = "redis"
  engine_version       = "7.1"
  node_type            = var.redis_node_type
  num_cache_nodes      = 1
  parameter_group_name = aws_elasticache_parameter_group.redis.name
  subnet_group_name    = aws_elasticache_subnet_group.redis.name
  security_group_ids   = [aws_security_group.elasticache.id]

  # Port
  port = 6379

  # Snapshots and backups
  snapshot_retention_limit = 1
  snapshot_window          = "03:00-05:00"
  maintenance_window       = "mon:05:00-mon:07:00"

  # Notifications (optional)
  # notification_topic_arn = aws_sns_topic.elasticache_notifications.arn

  # Auto minor version upgrade
  auto_minor_version_upgrade = true

  # Note: Encryption at rest and in transit require Redis AUTH and are only
  # available with replication groups (not single-node clusters)
  # For production with encryption, use aws_elasticache_replication_group instead

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-redis"
  })
}

# ============================================================================
# CloudWatch Alarms for ElastiCache
# ============================================================================

resource "aws_cloudwatch_metric_alarm" "redis_cpu" {
  alarm_name          = "${var.project_name}-${var.environment}-redis-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Average"
  threshold           = 75
  alarm_description   = "This metric monitors redis cpu utilization"

  dimensions = {
    CacheClusterId = aws_elasticache_cluster.redis.id
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "redis_memory" {
  alarm_name          = "${var.project_name}-${var.environment}-redis-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseMemoryUsagePercentage"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "This metric monitors redis memory utilization"

  dimensions = {
    CacheClusterId = aws_elasticache_cluster.redis.id
  }

  tags = local.common_tags
}
