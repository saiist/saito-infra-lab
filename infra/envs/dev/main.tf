module "vpc" {
  source = "../../modules/vpc"

  project = var.project
  env     = var.env

  vpc_cidr            = var.vpc_cidr
  azs                 = var.azs
  public_subnet_cidrs = var.public_subnet_cidrs
  app_subnet_cidrs    = var.app_subnet_cidrs
  db_subnet_cidrs     = var.db_subnet_cidrs

  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = var.single_nat_gateway
}

module "security" {
  source = "../../modules/security"

  project = var.project
  env     = var.env
  vpc_id  = module.vpc.vpc_id
}

data "aws_route53_zone" "this" {
  name         = "${var.domain_name}."
  private_zone = false
}

module "alb" {
  source = "../../modules/alb"

  project = var.project
  env     = var.env

  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  alb_sg_id         = module.security.alb_sg_id

  zone_id   = data.aws_route53_zone.this.zone_id
  zone_name = var.domain_name

  record_name = var.api_record_name
}

module "ecs" {
  source  = "../../modules/ecs"
  project = var.project
  env     = var.env
}
