resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.project}/${var.env}/app"
  retention_in_days = 7
}

resource "aws_ecs_cluster" "this" {
  name = "${var.project}-${var.env}-cluster"
}

data "aws_iam_policy_document" "ecs_task_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "execution" {
  name               = "${var.project}-${var.env}-ecs-exec"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json
}

resource "aws_iam_role_policy_attachment" "execution_managed" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# （明示）ログ出力。環境によってはmanaged policyで足りるが、学習では見える化しておく
data "aws_iam_policy_document" "execution_extra" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["${aws_cloudwatch_log_group.app.arn}:*"]
  }
}

resource "aws_iam_policy" "execution_extra" {
  name   = "${var.project}-${var.env}-ecs-exec-extra"
  policy = data.aws_iam_policy_document.execution_extra.json
}

resource "aws_iam_role_policy_attachment" "execution_extra" {
  role       = aws_iam_role.execution.name
  policy_arn = aws_iam_policy.execution_extra.arn
}

resource "aws_iam_role" "task" {
  name               = "${var.project}-${var.env}-ecs-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json
}

resource "aws_ecs_service" "app" {
  name            = "${var.project}-${var.env}-app-svc"
  cluster         = aws_ecs_cluster.this.id
  task_definition = var.initial_task_definition_arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.app_subnet_ids
    security_groups  = [var.ecs_sg_id]
    assign_public_ip = false
  }

  load_balancer {
    # Blue/Green時は primary TG（blue）を指定
    target_group_arn = var.enable_blue_green ? var.primary_target_group_arn : var.target_group_arn
    container_name   = "app"
    container_port   = var.container_port

    dynamic "advanced_configuration" {
      for_each = var.enable_blue_green ? [1] : []
      content {
        alternate_target_group_arn = var.alternate_target_group_arn
        production_listener_rule   = var.production_listener_rule_arn
        role_arn                   = aws_iam_role.ecs_infra_lb.arn
        # test_listener_rule は今回は無し（必要なら後で追加）
      }
    }
  }

  dynamic "deployment_configuration" {
    for_each = var.enable_blue_green ? [1] : []
    content {
      strategy = "BLUE_GREEN"

      # “bake time”は新旧共存時間。学習なら短めでOK
      bake_time_in_minutes = 1
    }
  }

  # dev用途で「速く入れ替えたい／多少落ちてもOK」
  deployment_minimum_healthy_percent = var.enable_blue_green ? 100 : 0
  deployment_maximum_percent         = var.enable_blue_green ? 200 : 100

  force_delete          = true
  wait_for_steady_state = false

  lifecycle {
    ignore_changes = [
      task_definition,
    ]
  }
}


data "aws_iam_policy_document" "execution_secrets" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]
    resources = [
      var.db_secret_arn
    ]
  }
}

resource "aws_iam_policy" "execution_secrets" {
  name   = "${var.project}-${var.env}-ecs-exec-secrets"
  policy = data.aws_iam_policy_document.execution_secrets.json
}

resource "aws_iam_role_policy_attachment" "execution_secrets" {
  role       = aws_iam_role.execution.name
  policy_arn = aws_iam_policy.execution_secrets.arn
}

data "aws_iam_policy_document" "task_secrets" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]
    resources = [var.db_secret_arn]
  }
}

resource "aws_iam_role_policy" "task_secrets" {
  name   = "${var.project}-${var.env}-task-secrets"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.task_secrets.json
}

data "aws_iam_policy" "ecs_infra_lb" {
  arn = "arn:aws:iam::aws:policy/AmazonECSInfrastructureRolePolicyForLoadBalancers"
}

resource "aws_iam_role" "ecs_infra_lb" {
  name = "${var.project}-${var.env}-ecs-infra-lb"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_infra_lb" {
  role       = aws_iam_role.ecs_infra_lb.name
  policy_arn = data.aws_iam_policy.ecs_infra_lb.arn
}
