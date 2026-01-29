# ---- SNS topic + email subscription ----
resource "aws_sns_topic" "alarms" {
  name = "${var.project}-${var.env}-alarms"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# NOTE: Emailは「承認リンク」を踏むまで通知が飛ばない

# ---- CloudWatch Alarms ----
locals {
  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]
}

# ========== ALB ==========
resource "aws_cloudwatch_metric_alarm" "alb_target_5xx_blue" {
  alarm_name          = "${var.project}-${var.env}-alb-target-5xx-blue"
  alarm_description   = "ALB target 5xx errors (blue)"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.tg_blue_arn_suffix
  }

  treat_missing_data = "notBreaching"
  alarm_actions      = local.alarm_actions
  ok_actions         = local.ok_actions
}

resource "aws_cloudwatch_metric_alarm" "alb_target_5xx_green" {
  alarm_name          = "${var.project}-${var.env}-alb-target-5xx-green"
  alarm_description   = "ALB target 5xx errors (green)"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.tg_green_arn_suffix
  }

  treat_missing_data = "notBreaching"
  alarm_actions      = local.alarm_actions
  ok_actions         = local.ok_actions
}

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_hosts_blue" {
  alarm_name          = "${var.project}-${var.env}-alb-unhealthy-hosts-blue"
  alarm_description   = "UnHealthyHostCount > 0 (blue)"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.tg_blue_arn_suffix
  }

  treat_missing_data = "notBreaching"

  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions
}

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_hosts_green" {
  alarm_name          = "${var.project}-${var.env}-alb-unhealthy-hosts-green"
  alarm_description   = "UnHealthyHostCount > 0 (green)"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.tg_green_arn_suffix
  }

  treat_missing_data = "notBreaching"

  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions
}

resource "aws_cloudwatch_metric_alarm" "alb_target_response_time_blue" {
  alarm_name          = "${var.project}-${var.env}-alb-target-response-time-blue"
  alarm_description   = "TargetResponseTime is high (tune threshold for your app) (blue)"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "TargetResponseTime"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 3
  threshold           = 1.0
  comparison_operator = "GreaterThanThreshold"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.tg_blue_arn_suffix
  }

  treat_missing_data = "notBreaching"

  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions
}

resource "aws_cloudwatch_metric_alarm" "alb_target_response_time_green" {
  alarm_name          = "${var.project}-${var.env}-alb-target-response-time-green"
  alarm_description   = "TargetResponseTime is high (tune threshold for your app) (green)"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "TargetResponseTime"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 3
  threshold           = 1.0
  comparison_operator = "GreaterThanThreshold"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.tg_green_arn_suffix
  }

  treat_missing_data = "notBreaching"

  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions
}

# ========== ECS（service level） ==========
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  alarm_name          = "${var.project}-${var.env}-ecs-cpu-high"
  alarm_description   = "ECS service CPU utilization is high"
  namespace           = "AWS/ECS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 5
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.ecs_service_name
  }

  treat_missing_data = "notBreaching"

  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions
}

resource "aws_cloudwatch_metric_alarm" "ecs_memory_high" {
  alarm_name          = "${var.project}-${var.env}-ecs-memory-high"
  alarm_description   = "ECS service memory utilization is high"
  namespace           = "AWS/ECS"
  metric_name         = "MemoryUtilization"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 5
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.ecs_service_name
  }

  treat_missing_data = "notBreaching"

  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions
}

# ========== RDS ==========
resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  alarm_name          = "${var.project}-${var.env}-rds-cpu-high"
  alarm_description   = "RDS CPUUtilization is high"
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 5
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"

  dimensions = {
    DBInstanceIdentifier = var.db_identifier
  }

  treat_missing_data = "notBreaching"

  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions
}

resource "aws_cloudwatch_metric_alarm" "rds_free_storage_low" {
  alarm_name          = "${var.project}-${var.env}-rds-free-storage-low"
  alarm_description   = "RDS FreeStorageSpace is low (bytes)"
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  statistic           = "Minimum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 2 * 1024 * 1024 * 1024 # 2 GiB
  comparison_operator = "LessThanThreshold"

  dimensions = {
    DBInstanceIdentifier = var.db_identifier
  }

  treat_missing_data = "notBreaching"

  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions
}

resource "aws_cloudwatch_metric_alarm" "rds_connections_high" {
  alarm_name          = "${var.project}-${var.env}-rds-connections-high"
  alarm_description   = "RDS DatabaseConnections is high (tune threshold)"
  namespace           = "AWS/RDS"
  metric_name         = "DatabaseConnections"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 5
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"

  dimensions = {
    DBInstanceIdentifier = var.db_identifier
  }

  treat_missing_data = "notBreaching"

  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions
}

# ---- CloudWatch Dashboard ----
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project}-${var.env}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric",
        width  = 12,
        height = 6,
        properties = {
          title  = "ALB: Target 5xx / Unhealthy / ResponseTime"
          region = var.region
          view   = "timeSeries"
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", var.alb_arn_suffix, "TargetGroup", var.tg_blue_arn_suffix, { "stat" : "Sum", "label" : "5xx blue" }],
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", var.alb_arn_suffix, "TargetGroup", var.tg_green_arn_suffix, { "stat" : "Sum", "label" : "5xx green" }],

            ["AWS/ApplicationELB", "UnHealthyHostCount", "LoadBalancer", var.alb_arn_suffix, "TargetGroup", var.tg_blue_arn_suffix, { "stat" : "Maximum", "label" : "unhealthy blue" }],
            ["AWS/ApplicationELB", "UnHealthyHostCount", "LoadBalancer", var.alb_arn_suffix, "TargetGroup", var.tg_green_arn_suffix, { "stat" : "Maximum", "label" : "unhealthy green" }],

            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix, "TargetGroup", var.tg_blue_arn_suffix, { "stat" : "Average", "yAxis" : "right", "label" : "rt blue" }],
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix, "TargetGroup", var.tg_green_arn_suffix, { "stat" : "Average", "yAxis" : "right", "label" : "rt green" }]
          ]
          period = 60
        }
      },
      {
        type   = "metric",
        width  = 12,
        height = 6,
        properties = {
          title  = "ECS: CPU / Memory"
          region = var.region
          view   = "timeSeries"
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", var.ecs_cluster_name, "ServiceName", var.ecs_service_name, { "stat" : "Average" }],
            ["AWS/ECS", "MemoryUtilization", "ClusterName", var.ecs_cluster_name, "ServiceName", var.ecs_service_name, { "stat" : "Average" }]
          ]
          period = 60
        }
      },
      {
        type   = "metric",
        width  = 12,
        height = 6,
        properties = {
          title  = "RDS: CPU / Connections / FreeStorage"
          region = var.region
          view   = "timeSeries"
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.db_identifier, { "stat" : "Average" }],
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", var.db_identifier, { "stat" : "Average" }],
            ["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", var.db_identifier, { "stat" : "Minimum", "yAxis" : "right" }]
          ]
          period = 60
        }
      }
    ]
  })
}
