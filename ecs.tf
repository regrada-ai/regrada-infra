# ecs.tf - ECS Cluster and Services

# ============================================================================
# ECS Cluster
# ============================================================================

resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-${var.environment}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = local.common_tags
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 1
    base              = 0
  }
}

# ============================================================================
# CloudWatch Log Groups
# ============================================================================

resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/${var.project_name}-${var.environment}-backend"
  retention_in_days = 7

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "frontend" {
  name              = "/ecs/${var.project_name}-${var.environment}-frontend"
  retention_in_days = 7

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "postgres" {
  name              = "/ecs/${var.project_name}-${var.environment}-postgres"
  retention_in_days = 7

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "redis" {
  name              = "/ecs/${var.project_name}-${var.environment}-redis"
  retention_in_days = 7

  tags = local.common_tags
}

# ============================================================================
# ECS Task Execution Role
# ============================================================================

resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.project_name}-${var.environment}-ecs-task-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ============================================================================
# ECS Task Role (for application permissions)
# ============================================================================

resource "aws_iam_role" "ecs_task" {
  name = "${var.project_name}-${var.environment}-ecs-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "ecs_task_cognito" {
  name = "${var.project_name}-${var.environment}-ecs-cognito-policy"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cognito-idp:*"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "ecs_task_s3" {
  count = var.s3_bucket != "" ? 1 : 0
  name  = "${var.project_name}-${var.environment}-ecs-s3-policy"
  role  = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "arn:aws:s3:::${var.s3_bucket}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "ecs_task_ses" {
  count = var.email_from_address != "" ? 1 : 0
  name  = "${var.project_name}-${var.environment}-ecs-ses-policy"
  role  = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail"
        ]
        Resource = "*"
      }
    ]
  })
}

# Redis is now provided by ElastiCache (see elasticache.tf)

# ============================================================================
# Backend API Task Definition
# ============================================================================

resource "aws_ecs_task_definition" "backend" {
  family                   = "${var.project_name}-${var.environment}-backend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "backend"
      image     = "${aws_ecr_repository.backend.repository_url}:latest"
      essential = true

      environment = [
        {
          name  = "PORT"
          value = tostring(var.backend_port)
        },
        {
          name  = "GIN_MODE"
          value = var.gin_mode
        },
        {
          name  = "SECURE_COOKIES"
          value = tostring(var.secure_cookies)
        },
        {
          name  = "DATABASE_URL"
          value = "postgres://${var.postgres_user}:${random_password.rds_password.result}@${aws_db_instance.postgres.endpoint}/${var.postgres_db}?sslmode=require"
        },
        {
          name  = "REDIS_URL"
          value = "redis://${aws_elasticache_cluster.redis.cache_nodes[0].address}:${aws_elasticache_cluster.redis.cache_nodes[0].port}"
        },
        {
          name  = "AWS_REGION"
          value = var.aws_region
        },
        {
          name  = "COGNITO_USER_POOL_ID"
          value = data.aws_cognito_user_pool.main.id
        },
        {
          name  = "COGNITO_CLIENT_ID"
          value = var.cognito_client_id
        },
        {
          name  = "COGNITO_CLIENT_SECRET"
          value = var.cognito_client_secret
        },
        {
          name  = "CORS_ALLOW_ORIGINS"
          value = "*"
        },
        {
          name  = "S3_BUCKET"
          value = data.aws_s3_bucket.user_assets.id
        },
        {
          name  = "CLOUDFRONT_DOMAIN"
          value = var.cloudfront_domain
        },
        {
          name  = "EMAIL_FROM_ADDRESS"
          value = var.email_from_address
        },
        {
          name  = "EMAIL_FROM_NAME"
          value = var.email_from_name
        }
      ]

      portMappings = [
        {
          containerPort = var.backend_port
          protocol      = "tcp"
        }
      ]

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${var.backend_port}/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.backend.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "backend"
        }
      }
    }
  ])

  tags = local.common_tags
}

# ============================================================================
# Frontend Task Definition
# ============================================================================

resource "aws_ecs_task_definition" "frontend" {
  family                   = "${var.project_name}-${var.environment}-frontend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name      = "frontend"
      image     = "${aws_ecr_repository.frontend.repository_url}:latest"
      essential = true

      environment = [
        {
          name  = "NEXT_PUBLIC_REGRADA_API_BASE_URL"
          value = "http://${aws_service_discovery_service.backend.name}.${aws_service_discovery_private_dns_namespace.main.name}:${var.backend_port}"
        },
        {
          name  = "PORT"
          value = tostring(var.frontend_port)
        }
      ]

      portMappings = [
        {
          containerPort = var.frontend_port
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.frontend.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "frontend"
        }
      }
    }
  ])

  tags = local.common_tags
}

# ============================================================================
# Service Discovery (Cloud Map)
# ============================================================================

resource "aws_service_discovery_private_dns_namespace" "main" {
  name        = "${var.project_name}.local"
  description = "Private DNS namespace for Regrada services"
  vpc         = aws_vpc.main.id

  tags = local.common_tags
}

# Infrastructure service discovery removed - using ElastiCache and RDS

resource "aws_service_discovery_service" "backend" {
  name = "backend"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  # ECS manages health checks via ALB target group health checks
  # No custom health check configuration needed

  tags = local.common_tags
}

# ============================================================================
# ECS Services
# ============================================================================

# Infrastructure ECS service removed - using ElastiCache and RDS

resource "aws_ecs_service" "backend" {
  name            = "${var.project_name}-${var.environment}-backend"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.private.id]
    security_groups  = [aws_security_group.backend.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend.arn
    container_name   = "backend"
    container_port   = var.backend_port
  }

  service_registries {
    registry_arn = aws_service_discovery_service.backend.arn
  }

  depends_on = [
    aws_lb_listener.http,
    aws_elasticache_cluster.redis,
    aws_db_instance.postgres
  ]

  tags = local.common_tags
}

resource "aws_ecs_service" "frontend" {
  name            = "${var.project_name}-${var.environment}-frontend"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.frontend.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.private.id]
    security_groups  = [aws_security_group.frontend.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend.arn
    container_name   = "frontend"
    container_port   = var.frontend_port
  }

  depends_on = [
    aws_lb_listener.http,
    aws_ecs_service.backend,
    aws_elasticache_cluster.redis,
    aws_db_instance.postgres
  ]

  tags = local.common_tags
}
