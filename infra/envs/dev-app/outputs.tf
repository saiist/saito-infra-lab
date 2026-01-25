output "api_fqdn" { value = module.alb.fqdn }
output "alb_dns" { value = module.alb.alb_dns_name }
output "tg_arn" { value = module.alb.tg_arn }

output "ecr_repo_url" { value = module.ecr.repo_url }
output "ecr_repo_name" { value = module.ecr.repo_name }

output "alarm_topic_arn" { value = module.observability.alarm_topic_arn }
output "dashboard_name" { value = module.observability.dashboard_name }

output "github_actions_role_arn" { value = module.cicd_github_oidc.github_actions_role_arn }
