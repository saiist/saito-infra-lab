resource "aws_cloudwatch_log_group" "waf" {
  count             = var.enable_waf ? 1 : 0
  name              = "aws-waf-logs-${var.project}-${var.env}-alb"
  retention_in_days = var.waf_log_retention_days
}

resource "aws_wafv2_web_acl" "this" {
  count = var.enable_waf ? 1 : 0

  name  = "${var.project}-${var.env}-waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project}-${var.env}-waf"
    sampled_requests_enabled   = true
  }

  # まずは定番のベースライン（軽め）2つ
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 10

    # countモードは観測のみ。blockモードはnone（=マネージドルール既定のアクションを有効化）
    override_action {
      dynamic "count" {
        for_each = var.waf_mode == "count" ? [1] : []
        content {}
      }
      dynamic "none" {
        for_each = var.waf_mode == "block" ? [1] : []
        content {}
      }
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project}-${var.env}-waf-common"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 20

    override_action {
      dynamic "count" {
        for_each = var.waf_mode == "count" ? [1] : []
        content {}
      }
      dynamic "none" {
        for_each = var.waf_mode == "block" ? [1] : []
        content {}
      }
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project}-${var.env}-waf-badinputs"
      sampled_requests_enabled   = true
    }
  }

  # Rate-based: 同一IPからの連打を制限（まずCOUNT→ログ観測、慣れたらBLOCK）
  rule {
    name     = "RateLimitPerIp"
    priority = 1

    action {
      dynamic "count" {
        for_each = var.waf_mode == "count" ? [1] : []
        content {}
      }
      dynamic "block" {
        for_each = var.waf_mode == "block" ? [1] : []
        content {}
      }
    }

    statement {
      rate_based_statement {
        # 5分間のリクエスト数で判定（WAFの標準ウィンドウ）
        # 学習用: 最初は低め(50〜200)にすると再現しやすい
        limit              = var.waf_rate_limit_per_ip
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project}-${var.env}-waf-rate-ip"
      sampled_requests_enabled   = true
    }
  }


  # Hostヘッダ制限は独自ルールで追加
  rule {
    name     = "EnforceHostHeader"
    priority = 2

    # countモードは観測のみ。blockモードはnone
    action {
      dynamic "count" {
        for_each = var.waf_mode == "count" ? [1] : []
        content {}
      }
      dynamic "block" {
        for_each = var.waf_mode == "block" ? [1] : []
        content {}
      }
    }

    statement {
      not_statement {
        statement {
          byte_match_statement {
            search_string = "api.dev.saito-infra-lab.click"

            field_to_match {
              single_header {
                name = "host"
              }
            }

            positional_constraint = "EXACTLY"

            text_transformation {
              priority = 0
              type     = "LOWERCASE"
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project}-${var.env}-waf-enforce-host"
      sampled_requests_enabled   = true
    }
  }

}

resource "aws_wafv2_web_acl_association" "alb" {
  count = var.enable_waf ? 1 : 0

  resource_arn = aws_lb.this.arn
  web_acl_arn  = aws_wafv2_web_acl.this[0].arn
}

resource "aws_wafv2_web_acl_logging_configuration" "this" {
  count = var.enable_waf ? 1 : 0

  resource_arn            = aws_wafv2_web_acl.this[0].arn
  log_destination_configs = ["${aws_cloudwatch_log_group.waf[0].arn}:*"]
}
