# SPDX-License-Identifier: LicenseRef-Regrada-Proprietary
# secrets.tf - AWS Secrets Manager

# ============================================================================
# RDS Master Password
# ============================================================================

resource "aws_secretsmanager_secret" "rds_password" {
  name        = "${var.project_name}-${var.environment}-rds-password"
  description = "PostgreSQL master password for RDS"

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "rds_password" {
  secret_id = aws_secretsmanager_secret.rds_password.id
  secret_string = jsonencode({
    username = var.postgres_user
    password = random_password.rds_password.result
  })
}

resource "random_password" "rds_password" {
  length  = 32
  special = true
  # Exclude characters that might cause issues in connection strings
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# ============================================================================
# Cognito Client Secret
# ============================================================================

resource "aws_secretsmanager_secret" "cognito_client_secret" {
  name        = "${var.project_name}-${var.environment}-cognito-client-secret"
  description = "AWS Cognito app client secret"

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "cognito_client_secret" {
  secret_id = aws_secretsmanager_secret.cognito_client_secret.id
  secret_string = jsonencode({
    user_pool_id  = data.aws_cognito_user_pool.main.id
    client_id     = var.cognito_client_id
    client_secret = var.cognito_client_secret
  })
}

# ============================================================================
# IAM Policy for ECS to access secrets
# ============================================================================

resource "aws_iam_role_policy" "ecs_secrets_access" {
  name = "${var.project_name}-${var.environment}-ecs-secrets-policy"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          aws_secretsmanager_secret.rds_password.arn,
          aws_secretsmanager_secret.cognito_client_secret.arn
        ]
      }
    ]
  })
}
