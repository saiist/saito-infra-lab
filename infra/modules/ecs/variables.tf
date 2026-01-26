variable "project" { type = string }
variable "env" { type = string }
variable "aws_region" { type = string }

variable "app_subnet_ids" { type = list(string) }
variable "ecs_sg_id" { type = string }

variable "target_group_arn" {
  type        = string
  description = "Rolling update用のTarget Group ARN（Blue/Green時は primary_target_group_arn を使う）"
  default     = null
}

variable "container_port" {
  type    = number
  default = 8080
}

variable "desired_count" {
  type    = number
  default = 1
}

variable "db_secret_arn" { type = string }

variable "initial_task_definition_arn" {
  type        = string
  description = "ECS service creation-time task definition ARN. After that, CI updates it; Terraform ignores changes."
}

variable "enable_blue_green" {
  description = "ECSネイティブBlue/Greenを有効化する"
  type        = bool
  default     = false
}

variable "primary_target_group_arn" {
  description = "Blue(現行)側のTarget Group ARN"
  type        = string
  default     = null

  validation {
    condition     = var.enable_blue_green == false || (var.primary_target_group_arn != null && var.primary_target_group_arn != "")
    error_message = "enable_blue_green=true のとき primary_target_group_arn は必須です"
  }
}

variable "alternate_target_group_arn" {
  description = "Green(新)側のTarget Group ARN"
  type        = string
  default     = null

  validation {
    condition     = var.enable_blue_green == false || (var.alternate_target_group_arn != null && var.alternate_target_group_arn != "")
    error_message = "enable_blue_green=true のとき alternate_target_group_arn は必須です"
  }
}

variable "production_listener_rule_arn" {
  description = "Production traffic用のALB listener rule ARN"
  type        = string
  default     = null

  validation {
    condition     = var.enable_blue_green == false || (var.production_listener_rule_arn != null && var.production_listener_rule_arn != "")
    error_message = "enable_blue_green=true のとき production_listener_rule_arn は必須です"
  }
}
