output "vpc_id" { value = module.vpc.vpc_id }

output "public_subnet_ids" { value = module.vpc.public_subnet_ids }
output "app_subnet_ids" { value = module.vpc.app_subnet_ids }
output "db_subnet_ids" { value = module.vpc.db_subnet_ids }

output "alb_sg_id" { value = module.security.alb_sg_id }
output "ecs_sg_id" { value = module.security.ecs_sg_id }
output "rds_sg_id" { value = module.security.rds_sg_id }

output "api_fqdn" { value = module.alb.fqdn }
output "alb_dns" { value = module.alb.alb_dns_name }
output "tg_arn" { value = module.alb.tg_arn }

output "ecr_repo_url" { value = module.ecr.repo_url }
output "ecr_repo_name" { value = module.ecr.repo_name }

output "db_endpoint" { value = module.rds.db_endpoint }
output "db_port" { value = module.rds.db_port }
output "db_secret_arn" { value = module.rds.secret_arn }
