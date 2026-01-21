variable "project" { type = string }
variable "env" { type = string }

variable "app_subnet_ids" { type = list(string) }
variable "ecs_sg_id" { type = string }

variable "target_group_arn" { type = string }

variable "container_image" { type = string } # 例: <ecr_url>:dev
variable "container_port" {
  type    = number
  default = 8080
}

variable "desired_count" {
  type    = number
  default = 1
}
