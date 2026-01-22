variable "project" {
  type = string
}

variable "env" {
  type = string
}

variable "region" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "app_subnet_ids" {
  type = list(string)
}

variable "ecs_sg_id" {
  type = string
}

variable "private_route_table_id" {
  type = string
}
