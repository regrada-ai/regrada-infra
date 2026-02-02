# SPDX-License-Identifier: LicenseRef-Regrada-Proprietary
# route53.tf - Route53 DNS Configuration
# Uses existing hosted zone from data-sources.tf

# ============================================================================
# ACM Certificate for HTTPS
# ============================================================================

resource "aws_acm_certificate" "main" {
  domain_name       = "regrada.com"
  validation_method = "DNS"

  subject_alternative_names = [
    "*.regrada.com"
  ]

  lifecycle {
    create_before_destroy = true
  }

  tags = local.common_tags
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.regrada.zone_id
}

resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# ============================================================================
# Route53 Records
# ============================================================================

# Apex domain (regrada.com) -> redirect to www.regrada.com
# This is handled by an S3 bucket redirect
resource "aws_s3_bucket" "redirect" {
  bucket = "regrada.com"

  tags = local.common_tags
}

resource "aws_s3_bucket_website_configuration" "redirect" {
  bucket = aws_s3_bucket.redirect.id

  redirect_all_requests_to {
    host_name = "www.regrada.com"
    protocol  = "https"
  }
}

resource "aws_s3_bucket_public_access_block" "redirect" {
  bucket = aws_s3_bucket.redirect.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "redirect" {
  bucket = aws_s3_bucket.redirect.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.redirect.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.redirect]
}

# Apex domain A record pointing to ALB (redirect handled by ALB rule)
resource "aws_route53_record" "apex" {
  zone_id = data.aws_route53_zone.regrada.zone_id
  name    = "regrada.com"
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}

# www.regrada.com -> ALB (frontend)
resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.regrada.zone_id
  name    = "www.regrada.com"
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}

# api.regrada.com -> ALB (backend)
resource "aws_route53_record" "api" {
  zone_id = data.aws_route53_zone.regrada.zone_id
  name    = "api.regrada.com"
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}

# ============================================================================
# Update ALB Listener for HTTPS
# ============================================================================

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate.main.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }

  tags = local.common_tags

  depends_on = [aws_acm_certificate_validation.main]
}

# HTTPS listener rules (same as HTTP)
resource "aws_lb_listener_rule" "backend_api_https" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }

  condition {
    path_pattern {
      values = ["/v1/*"]
    }
  }

  tags = local.common_tags
}

resource "aws_lb_listener_rule" "backend_health_https" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 101

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }

  condition {
    path_pattern {
      values = ["/health"]
    }
  }

  tags = local.common_tags
}

# Redirect apex domain (regrada.com) to www.regrada.com
resource "aws_lb_listener_rule" "redirect_apex_to_www" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 50

  action {
    type = "redirect"

    redirect {
      host        = "www.regrada.com"
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  condition {
    host_header {
      values = ["regrada.com"]
    }
  }

  tags = local.common_tags
}

# Redirect HTTP to HTTPS
resource "aws_lb_listener_rule" "redirect_http_to_https" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 1

  action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }

  tags = local.common_tags
}
