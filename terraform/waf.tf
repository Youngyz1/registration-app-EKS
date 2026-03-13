# ============================================
# WAF v2 — Web Application Firewall
#
# Attaches to the ALB created by the ALB Ingress Controller.
# Protects against:
#   - SQL injection
#   - XSS (Cross-site scripting)
#   - Known bad IPs (Amazon IP reputation list)
#   - Common attack patterns (AWS managed rules)
#   - Rate limiting (500 req/5min per IP)
# ============================================

resource "aws_wafv2_web_acl" "main" {
  name        = "${var.cluster_name}-waf"
  description = "WAF for registration app ALB"
  scope       = "REGIONAL" # Use CLOUDFRONT for CloudFront distributions

  default_action {
    allow {}
  }

  # ── Rule 1: AWS Managed — Common Rule Set (SQLi, XSS, etc.) ─────────────────
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {} # Use the rule group's own actions (block/count)
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  # ── Rule 2: AWS Managed — Known Bad Inputs ───────────────────────────────────
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesKnownBadInputsMetric"
      sampled_requests_enabled   = true
    }
  }

  # ── Rule 3: AWS Managed — Amazon IP Reputation List ─────────────────────────
  rule {
    name     = "AWSManagedRulesAmazonIpReputationList"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesAmazonIpReputationListMetric"
      sampled_requests_enabled   = true
    }
  }

  # ── Rule 4: SQL Injection Protection ────────────────────────────────────────
  rule {
    name     = "SQLiProtection"
    priority = 4

    action {
      block {}
    }

    statement {
      sqli_match_statement {
        field_to_match {
          body {}
        }
        text_transformation {
          priority = 1
          type     = "URL_DECODE"
        }
        text_transformation {
          priority = 2
          type     = "HTML_ENTITY_DECODE"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "SQLiProtectionMetric"
      sampled_requests_enabled   = true
    }
  }

  # ── Rule 5: Rate Limiting — 500 requests per 5 minutes per IP ───────────────
  # Protects registration endpoint from brute force / credential stuffing
  rule {
    name     = "RateLimitPerIP"
    priority = 5

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 500
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitPerIPMetric"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.cluster_name}-waf-metric"
    sampled_requests_enabled   = true
  }

  tags = {
    Name = "${var.cluster_name}-waf"
  }
}

# ── CloudWatch Log Group for WAF ──────────────────────────────────────────────
# WAF log group MUST be prefixed with "aws-waf-logs-"
resource "aws_cloudwatch_log_group" "waf" {
  name              = "aws-waf-logs-${var.cluster_name}"
  retention_in_days = 30
}

resource "aws_wafv2_web_acl_logging_configuration" "main" {
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]
  resource_arn            = aws_wafv2_web_acl.main.arn
}

# ── Outputs ────────────────────────────────────────────────────────────────────
output "waf_arn" {
  description = "WAF WebACL ARN — add to Helm values ingress annotation"
  value       = aws_wafv2_web_acl.main.arn
}

output "waf_id" {
  description = "WAF WebACL ID"
  value       = aws_wafv2_web_acl.main.id
}
