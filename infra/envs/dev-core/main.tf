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

module "rds" {
  source  = "../../modules/rds"
  project = var.project
  env     = var.env

  db_subnet_ids = module.vpc.db_subnet_ids
  rds_sg_id     = module.security.rds_sg_id

  db_name     = "app"
  db_username = "appuser"
}
