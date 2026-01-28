#!/bin/bash
# user-data.sh - EC2 initialization script for Regrada

set -e

# Update system
dnf update -y

# Install Docker
dnf install -y docker
systemctl start docker
systemctl enable docker
usermod -aG docker ec2-user

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

# Install Git
dnf install -y git

# Create app directory
mkdir -p /home/ec2-user/regrada
cd /home/ec2-user/regrada

# Create docker-compose.yml
cat > docker-compose.yml <<'EOF'
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    container_name: regrada-postgres
    environment:
      POSTGRES_USER: ${postgres_user}
      POSTGRES_PASSWORD: ${postgres_password}
      POSTGRES_DB: ${postgres_db}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${postgres_user}"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    container_name: regrada-redis
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

  backend:
    build:
      context: ./regrada-be
      dockerfile: Dockerfile
    container_name: regrada-backend
    environment:
      PORT: "${backend_port}"
      GIN_MODE: "${gin_mode}"
      SECURE_COOKIES: "${secure_cookies}"
      DATABASE_URL: "postgres://${postgres_user}:${postgres_password}@postgres:5432/${postgres_db}?sslmode=disable"
      REDIS_URL: "redis://redis:6379"
      AWS_REGION: "${aws_region}"
      COGNITO_USER_POOL_ID: "${cognito_user_pool_id}"
      COGNITO_CLIENT_ID: "${cognito_client_id}"
      COGNITO_CLIENT_SECRET: "${cognito_client_secret}"
      CORS_ALLOW_ORIGINS: "http://localhost:${frontend_port}"
      S3_BUCKET: "${s3_bucket}"
      CLOUDFRONT_DOMAIN: "${cloudfront_domain}"
      EMAIL_FROM_ADDRESS: "${email_from_address}"
      EMAIL_FROM_NAME: "${email_from_name}"
    ports:
      - "${backend_port}:${backend_port}"
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    restart: unless-stopped

  frontend:
    build:
      context: ./regrada-fe
      dockerfile: Dockerfile
    container_name: regrada-frontend
    environment:
      NEXT_PUBLIC_REGRADA_API_BASE_URL: "http://backend:${backend_port}"
    ports:
      - "${frontend_port}:${frontend_port}"
    depends_on:
      - backend
    restart: unless-stopped

volumes:
  postgres_data:
  redis_data:
EOF

# Create .env file with templated variables
cat > .env <<EOF
postgres_user=${postgres_user}
postgres_password=${postgres_password}
postgres_db=${postgres_db}
backend_port=${backend_port}
frontend_port=${frontend_port}
aws_region=${aws_region}
cognito_user_pool_id=${cognito_user_pool_id}
cognito_client_id=${cognito_client_id}
cognito_client_secret=${cognito_client_secret}
gin_mode=${gin_mode}
secure_cookies=${secure_cookies}
s3_bucket=${s3_bucket}
cloudfront_domain=${cloudfront_domain}
email_from_address=${email_from_address}
email_from_name=${email_from_name}
EOF

# Set proper permissions
chown -R ec2-user:ec2-user /home/ec2-user/regrada
chmod 600 /home/ec2-user/regrada/.env

# Note: You need to clone or copy your application code to:
# - /home/ec2-user/regrada/regrada-be
# - /home/ec2-user/regrada/regrada-fe
#
# Then run: docker-compose up -d --build
#
# This can be done manually or via a deployment script

echo "Setup complete! Application code needs to be deployed."
echo "Run: cd /home/ec2-user/regrada && docker-compose up -d --build"
