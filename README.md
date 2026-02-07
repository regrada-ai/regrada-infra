# Regrada Infrastructure

Terraform configuration for deploying Regrada to AWS using ECS, RDS, ElastiCache, and ALB.

## Architecture

Production-ready serverless architecture:

- **ECS Fargate**: Serverless container orchestration
- **Application Load Balancer**: HTTPS traffic routing with ACM certificate
- **RDS PostgreSQL**: Managed database with automated backups
- **ElastiCache Redis**: Managed caching layer
- **Route53**: DNS management with regrada.com domain
- **SES**: Email delivery service
- **ECR**: Docker image registry
- **API Gateway**: Additional API endpoint (optional)
- **Cognito**: User authentication (existing pool)
- **S3**: User-uploaded assets (existing bucket)
- **Secrets Manager**: Secure credential storage
- **CloudWatch**: Logging and monitoring

## Prerequisites

1. **AWS CLI** configured with appropriate credentials
2. **Terraform** v1.0+
3. **Docker** for building images
4. **GitHub repository** for CI/CD workflows

## Existing AWS Resources (Already Created)

The following resources are already set up and will be linked to the Terraform stack:

- **Cognito User Pool**: `us-east-1_yjgQiprWD` (User pool - ypj8ol)
- **Cognito Client**: `3676h3h2n7qv227s40mufjdipv` (Regrada App)
- **Route53 Hosted Zone**: `Z020639034BK26JZFNW6N` (regrada.com)
- **SES Verified Domain**: regrada.com
- **S3 Bucket**: regrada-user-assets

## Deployment

### 1. Configure Variables

The `terraform.tfvars` file already contains the configuration:

```hcl
aws_region   = "us-east-1"
project_name = "regrada"
environment  = "production"

# Cognito (existing)
cognito_client_id     = "3676h3h2n7qv227s40mufjdipv"
cognito_client_secret = "nsjbnecnobpccde321skm9tqbfmiu6rra831pivrsh9t1tlev1p"

# Database
postgres_user = "regrada"
postgres_db   = "regrada"
# Password is auto-generated and stored in Secrets Manager

# Application
backend_port   = 8080
frontend_port  = 3000
gin_mode       = "release"
secure_cookies = true

# Email
email_from_address = "noreply@regrada.com"
email_from_name    = "Regrada"
```

### 2. Initialize and Deploy

```bash
cd regrada-infra
terraform init
terraform plan
terraform apply
```

### 3. Set Up GitHub Actions

For automated deployments, configure GitHub secrets:

```bash
# Get AWS account ID
aws sts get-caller-identity --query Account --output text

# Create OIDC provider for GitHub Actions (if not exists)
# Follow: https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services
```

Add these secrets to your GitHub repositories:

- `AWS_ROLE_ARN`: IAM role ARN for GitHub Actions

### 4. Initial Image Push

After Terraform deployment, push initial Docker images:

```bash
# Login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $(aws sts get-caller-identity --query Account --output text).dkr.ecr.us-east-1.amazonaws.com

# Build and push backend
cd ../regrada-be
docker build -t regrada-production-backend:latest .
docker tag regrada-production-backend:latest $(terraform -chdir=../regrada-infra output -raw backend_ecr_repository_url):latest
docker push $(terraform -chdir=../regrada-infra output -raw backend_ecr_repository_url):latest

# Build and push frontend
cd ../regrada-fe
docker build --build-arg NEXT_PUBLIC_REGRADA_API_BASE_URL=https://api.regrada.com -t regrada-production-frontend:latest .
docker tag regrada-production-frontend:latest $(terraform -chdir=../regrada-infra output -raw frontend_ecr_repository_url):latest
docker push $(terraform -chdir=../regrada-infra output -raw frontend_ecr_repository_url):latest
```

### 5. Update ECS Services

```bash
aws ecs update-service --cluster regrada-production-cluster --service regrada-production-backend --force-new-deployment
aws ecs update-service --cluster regrada-production-cluster --service regrada-production-frontend --force-new-deployment
```

## DNS Configuration

The following DNS records are automatically created:

- **regrada.com** → S3 redirect to www.regrada.com
- **www.regrada.com** → ALB (frontend)
- **api.regrada.com** → ALB (backend)
- **mail.regrada.com** → SES mail FROM domain

## Accessing Services

Once deployed:

- **Website**: https://www.regrada.com (or https://regrada.com which redirects)
- **API**: https://api.regrada.com
- **API Gateway** (optional): Check outputs for URL

## CI/CD with GitHub Actions

Deployments are automated via GitHub Actions:

- **Push to main branch** → Triggers deployment workflow
- **Workflow builds Docker image** → Pushes to ECR
- **Updates ECS task definition** → Deploys new version
- **Waits for stability** → Ensures deployment succeeded

Workflows are located at:
- `/regrada-be/.github/workflows/deploy.yml`
- `/regrada-fe/.github/workflows/deploy.yml`

## Monitoring and Logs

### CloudWatch Logs

```bash
# Backend logs
aws logs tail /ecs/regrada-production-backend --follow

# Frontend logs
aws logs tail /ecs/regrada-production-frontend --follow
```

### CloudWatch Alarms

Alarms are configured for:
- Redis CPU utilization (>75%)
- Redis memory utilization (>80%)

### RDS Monitoring

- Enhanced monitoring enabled (60-second granularity)
- CloudWatch logs for PostgreSQL queries
- Automated backups with 7-day retention

## Security

- **Secrets Manager**: Stores RDS password and Cognito credentials
- **Private Subnets**: ECS tasks, RDS, and ElastiCache in private subnets
- **NAT Instance**: Outbound internet access for private resources via t4g.micro EC2
- **Security Groups**: Least-privilege network access
- **HTTPS Only**: ACM certificate with TLS 1.3
- **IAM Roles**: Task-specific permissions for ECS

## Secrets Management

Retrieve RDS password:

```bash
aws secretsmanager get-secret-value --secret-id regrada-production-rds-password --query SecretString --output text | jq -r '.password'
```

## Cost Estimate (Monthly)

| Service | Configuration | Estimated Cost |
|---------|--------------|----------------|
| ECS Fargate (Backend) | 0.25 vCPU, 0.5 GB | ~$10 |
| ECS Fargate (Frontend) | 0.25 vCPU, 0.5 GB | ~$10 |
| RDS (PostgreSQL) | db.t4g.micro | ~$15 |
| ElastiCache (Redis) | cache.t4g.micro | ~$12 |
| ALB | Active | ~$16 |
| NAT Instance | t4g.micro | ~$6 |
| Route53 | Hosted zone + queries | ~$1 |
| ACM Certificate | Free | $0 |
| ECR | <500 GB | ~$0-5 |
| CloudWatch Logs | Moderate usage | ~$3-5 |
| **Total** | | **~$73-80/month** |

## Scaling

The infrastructure is already scalable:

- **ECS Fargate**: Add auto-scaling policies based on CPU/memory
- **RDS**: Increase instance size or enable Multi-AZ
- **ElastiCache**: Add read replicas or use cluster mode
- **ALB**: Automatically scales with traffic

Example auto-scaling configuration:

```hcl
resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = 4
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.backend.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "ecs_policy" {
  name               = "scale-based-on-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 70.0
  }
}
```

## Troubleshooting

### ECS Task Not Starting

```bash
# Check ECS service events
aws ecs describe-services --cluster regrada-production-cluster --services regrada-production-backend

# Check task logs
aws ecs describe-tasks --cluster regrada-production-cluster --tasks <task-id>
```

### Cannot Connect to RDS

Ensure:
1. Security group allows inbound from ECS tasks
2. Database is in private subnet
3. Connection string is correct in environment variables

### Redis Connection Issues

Check:
1. ElastiCache security group allows inbound from backend
2. Redis endpoint is correctly configured in backend environment

## Maintenance

### Database Backups

Automated backups are enabled:
- Retention: 7 days
- Backup window: 03:00-04:00 UTC
- Maintenance window: Monday 04:00-05:00 UTC

### Manual Backup

```bash
aws rds create-db-snapshot \
  --db-instance-identifier regrada-production-postgres \
  --db-snapshot-identifier regrada-manual-snapshot-$(date +%Y%m%d)
```

### Updating Infrastructure

```bash
# Make changes to .tf files
terraform plan
terraform apply
```

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

**Warning**: This will delete all data. Ensure you have backups before destroying.

## Support

For issues or questions:
- Check CloudWatch logs
- Review ECS task events
- Check Terraform state: `terraform show`
- AWS Support (if applicable)

## Additional Resources

- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS ECS Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)

## License

This project is proprietary software owned by Regrada, Inc.
All rights reserved.

No use, reproduction, modification, or distribution is permitted
without explicit written authorization from Regrada, Inc.
