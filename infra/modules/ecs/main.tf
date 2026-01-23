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

# Terraformから aws_ecs_task_definition をやめてCIに寄せる
# resource "aws_ecs_task_definition" "app" {
#   family                   = "${var.project}-${var.env}-app"
#   requires_compatibilities = ["FARGATE"]
#   network_mode             = "awsvpc"
#   cpu                      = "256"
#   memory                   = "512"

#   execution_role_arn = aws_iam_role.execution.arn
#   task_role_arn      = aws_iam_role.task.arn

#   container_definitions = jsonencode([
#     {
#       name      = "app"
#       image     = var.container_image
#       essential = true

#       portMappings = [
#         { containerPort = var.container_port, protocol = "tcp" }
#       ]

#       environment = [
#         { name = "ENV", value = var.env },
#         { name = "PORT", value = tostring(var.container_port) },

#         { name = "DB_HOST", value = var.db_host },
#         { name = "DB_PORT", value = tostring(var.db_port) },
#         { name = "DB_NAME", value = var.db_name }
#       ]

#       secrets = [
#         {
#           name      = "DB_SECRET_JSON"
#           valueFrom = var.db_secret_arn
#         }
#       ]

#       logConfiguration = {
#         logDriver = "awslogs"
#         options = {
#           awslogs-group         = aws_cloudwatch_log_group.app.name
#           awslogs-region        = var.aws_region
#           awslogs-stream-prefix = "app"
#         }
#       }
#     }
#   ])

#   runtime_platform {
#     operating_system_family = "LINUX"
#     cpu_architecture        = "X86_64"
#   }

# }


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
    target_group_arn = var.target_group_arn
    container_name   = "app"
    container_port   = var.container_port
  }

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  lifecycle {
    ignore_changes = [
      task_definition
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
