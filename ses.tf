# ses.tf - AWS SES Configuration
# Uses existing verified domain from data-sources.tf (regrada.com)

# ============================================================================
# SES DKIM Configuration
# ============================================================================

# DKIM records for domain verification (domain already verified, managed via console)
resource "aws_ses_domain_dkim" "regrada" {
  domain = "regrada.com"
}

# Note: DKIM DNS records should already exist. If not, add them:
# resource "aws_route53_record" "ses_dkim" {
#   count   = 3
#   zone_id = data.aws_route53_zone.regrada.zone_id
#   name    = "${aws_ses_domain_dkim.regrada.dkim_tokens[count.index]}._domainkey.regrada.com"
#   type    = "CNAME"
#   ttl     = "600"
#   records = ["${aws_ses_domain_dkim.regrada.dkim_tokens[count.index]}.dkim.amazonses.com"]
# }

# ============================================================================
# Mail FROM Domain
# ============================================================================

resource "aws_ses_domain_mail_from" "regrada" {
  domain           = "regrada.com"
  mail_from_domain = "mail.regrada.com"
}

# MX record for mail FROM domain
resource "aws_route53_record" "ses_mail_from_mx" {
  zone_id = data.aws_route53_zone.regrada.zone_id
  name    = aws_ses_domain_mail_from.regrada.mail_from_domain
  type    = "MX"
  ttl     = "600"
  records = ["10 feedback-smtp.${var.aws_region}.amazonses.com"]
}

# TXT record for mail FROM domain
resource "aws_route53_record" "ses_mail_from_txt" {
  zone_id = data.aws_route53_zone.regrada.zone_id
  name    = aws_ses_domain_mail_from.regrada.mail_from_domain
  type    = "TXT"
  ttl     = "600"
  records = ["v=spf1 include:amazonses.com ~all"]
}

# ============================================================================
# SES Configuration Set
# ============================================================================

resource "aws_ses_configuration_set" "main" {
  name = "${var.project_name}-${var.environment}-config-set"
}

# Event destination for bounce and complaint tracking
resource "aws_sns_topic" "ses_events" {
  name = "${var.project_name}-${var.environment}-ses-events"

  tags = local.common_tags
}

resource "aws_ses_event_destination" "main" {
  name                   = "${var.project_name}-${var.environment}-events"
  configuration_set_name = aws_ses_configuration_set.main.name
  enabled                = true
  matching_types         = ["bounce", "complaint", "reject"]

  sns_destination {
    topic_arn = aws_sns_topic.ses_events.arn
  }
}
