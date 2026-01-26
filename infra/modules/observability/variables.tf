variable "project" {
  type = string
}

variable "env" {
  type = string
}

variable "region" {
  type = string
}

variable "alarm_email" {
  type = string
}

# ALB
variable "alb_arn_suffix" {
  type = string
}

variable "tg_arn_suffix" {
  type    = string
  default = null
}

# ECS
variable "ecs_cluster_name" {
  type = string
}

variable "ecs_service_name" {
  type = string
}

# RDS
variable "db_identifier" {
  type = string
}
