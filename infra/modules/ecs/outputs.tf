output "cluster_name" { value = aws_ecs_cluster.this.name }
output "service_name" { value = aws_ecs_service.app.name }
output "log_group_name" { value = aws_cloudwatch_log_group.app.name }

output "ecs_execution_role_arn" {
  value = aws_iam_role.execution.arn
}

output "ecs_task_role_arn" {
  value = aws_iam_role.task.arn
}

output "service_arn" {
  value = aws_ecs_service.app.id
}
