locals {
  role_name   = "${var.project}-${var.env}-github-actions-deploy"
  policy_name = "${var.project}-${var.env}-github-actions-deploy"
}

# GitHub Actions OIDC Provider（アカウントに1つでOKだが、既存がなければ作る）
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  # GitHub OIDC のthumbprint（一般にこの値で運用されている）
  # もし将来エラーが出たら更新が必要になる可能性あり。
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # main ブランチ固定（超重要）
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_owner}/${var.github_repo}:ref:${var.github_ref}"]
    }
  }
}

resource "aws_iam_role" "deploy" {
  name               = local.role_name
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}


data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "deploy" {
  # ECR login（* が必要）
  statement {
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  # ECR push（対象repoに限定）
  statement {
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
      "ecr:GetDownloadUrlForLayer",
      "ecr:DescribeImages"
    ]
    resources = [var.ecr_repository_arn]
  }

  # ECS service更新（serviceを限定）
  statement {
    effect = "Allow"
    actions = [
      "ecs:DescribeServices",
      "ecs:UpdateService"
    ]
    resources = [var.ecs_service_arn]
  }

  # task definition 登録は "*" が現実的（revisionが増えるため）
  statement {
    effect = "Allow"
    actions = [
      "ecs:RegisterTaskDefinition",
      "ecs:DescribeTaskDefinition"
    ]
    resources = ["*"]
  }

  # task definition に指定する role を PassRole
  statement {
    effect  = "Allow"
    actions = ["iam:PassRole"]
    resources = [
      var.ecs_task_execution_role_arn,
      var.ecs_task_role_arn
    ]
  }

  # SSM Parameter Store から DB secret ARN を取得
  statement {
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters"
    ]
    resources = [
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/saito-infra-lab/dev/db_secret_arn"
    ]
  }

}

resource "aws_iam_policy" "deploy" {
  name   = local.policy_name
  policy = data.aws_iam_policy_document.deploy.json
}

resource "aws_iam_role_policy_attachment" "deploy" {
  role       = aws_iam_role.deploy.name
  policy_arn = aws_iam_policy.deploy.arn
}
