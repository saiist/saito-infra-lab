output "github_actions_role_arn" {
  value = aws_iam_role.deploy.arn
}

output "github_actions_role_name" {
  value = aws_iam_role.deploy.name
}
