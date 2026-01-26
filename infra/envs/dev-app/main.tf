data "aws_route53_zone" "this" {
  name         = "${var.domain_name}."
  private_zone = false
}

module "ecr" {
  source  = "../../modules/ecr"
  project = var.project
  env     = var.env
}

module "alb" {
  source = "../../modules/alb"

  project = var.project
  env     = var.env

  vpc_id            = data.terraform_remote_state.core.outputs.vpc_id
  public_subnet_ids = data.terraform_remote_state.core.outputs.public_subnet_ids
  alb_sg_id         = data.terraform_remote_state.core.outputs.alb_sg_id

  zone_id     = data.aws_route53_zone.this.zone_id
  zone_name   = var.domain_name
  record_name = var.api_record_name

  # access logs を入れてるならここも渡す（デフォルトtrue/3日なら不要）
  enable_access_logs         = true
  access_logs_retention_days = 3

  enable_waf             = true
  waf_mode               = "block"
  waf_log_retention_days = 3
}

module "vpc_endpoints" {
  source = "../../modules/vpc_endpoints"

  project = var.project
  env     = var.env
  region  = var.aws_region

  vpc_id                 = data.terraform_remote_state.core.outputs.vpc_id
  app_subnet_ids         = data.terraform_remote_state.core.outputs.app_subnet_ids
  ecs_sg_id              = data.terraform_remote_state.core.outputs.ecs_sg_id
  private_route_table_id = data.terraform_remote_state.core.outputs.private_route_table_id
}

module "ecs" {
  source     = "../../modules/ecs"
  project    = var.project
  env        = var.env
  aws_region = var.aws_region

  app_subnet_ids = data.terraform_remote_state.core.outputs.app_subnet_ids
  ecs_sg_id      = data.terraform_remote_state.core.outputs.ecs_sg_id

  # --- Blue/Green (ECS native) ---
  enable_blue_green            = true
  primary_target_group_arn     = module.alb.primary_target_group_arn
  alternate_target_group_arn   = module.alb.alternate_target_group_arn
  production_listener_rule_arn = module.alb.production_listener_rule_arn

  db_secret_arn = data.terraform_remote_state.core.outputs.db_secret_arn

  initial_task_definition_arn = var.initial_task_definition_arn

  depends_on = [module.alb, module.vpc_endpoints]
}

module "observability" {
  source = "../../modules/observability"

  project = var.project
  env     = var.env
  region  = var.aws_region

  alarm_email = var.alarm_email

  alb_arn_suffix = module.alb.alb_arn_suffix
  # TODO: Remove after alb module output fixed
  tg_arn_suffix = null

  ecs_cluster_name = module.ecs.cluster_name
  ecs_service_name = module.ecs.service_name

  db_identifier = data.terraform_remote_state.core.outputs.db_identifier
}

module "cicd_github_oidc" {
  source = "../../modules/cicd_github_oidc"

  project    = var.project
  env        = var.env
  aws_region = var.aws_region

  github_owner = "saiist"
  github_repo  = "saito-infra-lab"
  github_ref   = "refs/heads/main"

  ecr_repository_arn = module.ecr.repo_arn
  ecs_service_arn    = module.ecs.service_arn

  ecs_task_execution_role_arn = module.ecs.ecs_execution_role_arn
  ecs_task_role_arn           = module.ecs.ecs_task_role_arn
}
