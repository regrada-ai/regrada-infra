# Deployment Guide

## Prerequisites Checklist

- [x] AWS CLI configured with credentials
- [x] Terraform installed
- [x] Docker installed
- [x] GitHub Actions role configured
- [x] Cognito User Pool exists
- [x] Route53 hosted zone exists
- [x] SES domain verified

## Step-by-Step Deployment

### Step 1: Initialize and Deploy Infrastructure

```bash
cd regrada-infra

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Deploy (this will take 10-15 minutes)
terraform apply
```

**What gets created:**
- VPC with public/private subnets, NAT Gateway
- RDS PostgreSQL instance (takes ~5 min)
- ElastiCache Redis cluster (takes ~3 min)
- ECS Cluster and task definitions
- ECR repositories (backend & frontend)
- Application Load Balancer
- Route53 DNS records
- ACM certificate (with auto-validation)
- Security groups and IAM roles
- Secrets Manager entries

**Important:** The ECS services will initially fail to start because no Docker images exist yet. This is expected!

### Step 2: Get ECR Repository URLs

```bash
# Save these for the next step
terraform output backend_ecr_repository_url
terraform output frontend_ecr_repository_url

# Should output something like:
# 985274299679.dkr.ecr.us-east-1.amazonaws.com/regrada-production-backend
# 985274299679.dkr.ecr.us-east-1.amazonaws.com/regrada-production-frontend
```

### Step 3: Build and Push Backend Image

```bash
cd ../regrada-be

# Login to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  985274299679.dkr.ecr.us-east-1.amazonaws.com

# Build the image
docker build -t regrada-backend:latest .

# Tag for ECR (replace with your actual ECR URL from terraform output)
BACKEND_ECR=$(cd ../regrada-infra && terraform output -raw backend_ecr_repository_url)
docker tag regrada-backend:latest $BACKEND_ECR:latest
docker tag regrada-backend:latest $BACKEND_ECR:$(git rev-parse --short HEAD)

# Push to ECR
docker push $BACKEND_ECR:latest
docker push $BACKEND_ECR:$(git rev-parse --short HEAD)

echo "✅ Backend image pushed successfully"
```

### Step 4: Build and Push Frontend Image

```bash
cd ../regrada-fe

# Build the image with production API URL
docker build \
  --build-arg NEXT_PUBLIC_REGRADA_API_BASE_URL=https://api.regrada.com \
  -t regrada-frontend:latest .

# Tag for ECR
FRONTEND_ECR=$(cd ../regrada-infra && terraform output -raw frontend_ecr_repository_url)
docker tag regrada-frontend:latest $FRONTEND_ECR:latest
docker tag regrada-frontend:latest $FRONTEND_ECR:$(git rev-parse --short HEAD)

# Push to ECR
docker push $FRONTEND_ECR:latest
docker push $FRONTEND_ECR:$(git rev-parse --short HEAD)

echo "✅ Frontend image pushed successfully"
```

### Step 5: Force ECS Service Update

Now that images are in ECR, force ECS to deploy them:

```bash
# Update backend service
aws ecs update-service \
  --cluster regrada-production-cluster \
  --service regrada-production-backend \
  --force-new-deployment \
  --region us-east-1

# Update frontend service
aws ecs update-service \
  --cluster regrada-production-cluster \
  --service regrada-production-frontend \
  --force-new-deployment \
  --region us-east-1

echo "✅ ECS services updating..."
echo "This will take 3-5 minutes for tasks to start"
```

### Step 6: Monitor Deployment

```bash
# Watch backend service
aws ecs describe-services \
  --cluster regrada-production-cluster \
  --services regrada-production-backend \
  --region us-east-1 \
  --query 'services[0].events[0:5]'

# Watch frontend service
aws ecs describe-services \
  --cluster regrada-production-cluster \
  --services regrada-production-frontend \
  --region us-east-1 \
  --query 'services[0].events[0:5]'

# Check running tasks
aws ecs list-tasks \
  --cluster regrada-production-cluster \
  --region us-east-1

# View logs (replace TASK_ID with actual task ID from above)
aws logs tail /ecs/regrada-production-backend --follow --region us-east-1
```

### Step 7: Verify Deployment

```bash
# Get ALB DNS name
cd ../regrada-infra
terraform output alb_dns_name

# Test backend health (may take a few minutes for DNS to propagate)
curl https://api.regrada.com/health

# Expected response: {"status":"ok"}

# Test frontend
curl -I https://www.regrada.com
# Expected: HTTP 200
```

### Step 8: Check DNS Propagation

```bash
# Check if DNS records are set
dig www.regrada.com +short
dig api.regrada.com +short

# Both should return ALB addresses
# DNS propagation can take 5-10 minutes
```

### Step 9: Verify Certificate

```bash
# Check certificate status
aws acm describe-certificate \
  --certificate-arn $(cd regrada-infra && terraform output -raw acm_certificate_arn) \
  --region us-east-1 \
  --query 'Certificate.Status'

# Should return: "ISSUED"
```

## Post-Deployment

### 1. Test the Application

- Visit https://www.regrada.com
- Try signing up/logging in
- Test API endpoints at https://api.regrada.com

### 2. Check Database Connection

```bash
# Get RDS endpoint
cd regrada-infra
terraform output rds_endpoint

# Get password
aws secretsmanager get-secret-value \
  --secret-id regrada-production-rds-password \
  --region us-east-1 \
  --query SecretString \
  --output text | jq -r '.password'

# Connect from within VPC (if needed for debugging)
# Note: RDS is in private subnet, not directly accessible
```

### 3. Monitor Costs

```bash
# Check current month costs
aws ce get-cost-and-usage \
  --time-period Start=$(date -u -d '1 month ago' +%Y-%m-%d),End=$(date -u +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE \
  --region us-east-1
```

## Future Deployments (Automated)

Once initial deployment is complete, all future deployments are automatic:

1. **Push to main branch** in regrada-be or regrada-fe
2. **GitHub Actions triggers** automatically
3. **Builds Docker image**
4. **Pushes to ECR**
5. **Updates ECS service**
6. **Waits for deployment to stabilize**

No manual intervention needed! 🎉

## Troubleshooting

### ECS Tasks Not Starting

```bash
# Check task stopped reason
aws ecs describe-tasks \
  --cluster regrada-production-cluster \
  --tasks $(aws ecs list-tasks --cluster regrada-production-cluster --query 'taskArns[0]' --output text) \
  --region us-east-1 \
  --query 'tasks[0].stoppedReason'

# Common issues:
# - "CannotPullContainerError" - Image doesn't exist in ECR yet
# - "ResourceInitializationError" - Check security groups
# - "Essential container exited" - Check application logs
```

### View Application Logs

```bash
# Backend logs
aws logs tail /ecs/regrada-production-backend --follow --region us-east-1

# Frontend logs
aws logs tail /ecs/regrada-production-frontend --follow --region us-east-1

# Filter for errors
aws logs filter-log-events \
  --log-group-name /ecs/regrada-production-backend \
  --filter-pattern ERROR \
  --region us-east-1
```

### Cannot Connect to Database

```bash
# Check security group rules
aws ec2 describe-security-groups \
  --filters "Name=tag:Name,Values=regrada-production-rds-sg" \
  --region us-east-1 \
  --query 'SecurityGroups[0].IpPermissions'

# Verify RDS is available
aws rds describe-db-instances \
  --db-instance-identifier regrada-production-postgres \
  --region us-east-1 \
  --query 'DBInstances[0].DBInstanceStatus'
```

### DNS Not Resolving

```bash
# Check Route53 records
aws route53 list-resource-record-sets \
  --hosted-zone-id Z020639034BK26JZFNW6N \
  --query "ResourceRecordSets[?Name=='www.regrada.com.']"

# Flush local DNS cache (macOS)
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
```

### Certificate Not Validating

```bash
# Check certificate validation records
aws acm describe-certificate \
  --certificate-arn $(cd regrada-infra && terraform output -raw acm_certificate_arn) \
  --region us-east-1 \
  --query 'Certificate.DomainValidationOptions'

# Validation records should be in Route53
# Check if they exist
aws route53 list-resource-record-sets \
  --hosted-zone-id Z020639034BK26JZFNW6N \
  --query "ResourceRecordSets[?Type=='CNAME']"
```

## Rollback

If something goes wrong:

```bash
# Rollback to previous task definition
aws ecs update-service \
  --cluster regrada-production-cluster \
  --service regrada-production-backend \
  --task-definition regrada-production-backend:PREVIOUS_VERSION \
  --region us-east-1
```

## Cleanup (if needed)

```bash
cd regrada-infra
terraform destroy

# Note: This will delete EVERYTHING including the database!
# Make sure you have backups first
```

## Support

- Check CloudWatch Logs for application errors
- Review ECS service events for deployment issues
- Check Terraform state: `terraform show`
- Review security group rules if connectivity issues
