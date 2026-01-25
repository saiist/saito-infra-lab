variable "aws_region" {
  type    = string
  default = "ap-northeast-1"
}

variable "project" {
  type    = string
  default = "saito-infra-lab"
}

variable "env" {
  type    = string
  default = "dev"
}

variable "domain_name" {
  type    = string
  default = "saito-infra-lab.click"
}

variable "api_record_name" {
  type    = string
  default = "api.dev"
}


variable "alarm_email" {
  type = string
}

variable "initial_task_definition_arn" {
  type = string
}
