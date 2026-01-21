variable "project" { type = string }
variable "env" { type = string }

variable "vpc_id" { type = string }
variable "public_subnet_ids" { type = list(string) }
variable "alb_sg_id" { type = string }

variable "zone_id" { type = string }   # Route53 Hosted Zone ID
variable "zone_name" { type = string } # saito-infra-lab.click

variable "record_name" { type = string } # api.dev

variable "enable_forward_to_tg" {
  type    = bool
  default = false
}
