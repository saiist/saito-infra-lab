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

variable "enable_access_logs" {
  type    = bool
  default = true
}

variable "access_logs_retention_days" {
  type    = number
  default = 3
}

variable "enable_waf" {
  description = "ALBにWAFv2を付けるか（dev用）"
  type        = bool
  default     = false
}

variable "waf_mode" {
  description = "count: 観測のみ / block: ブロック有効"
  type        = string
  default     = "count"

  validation {
    condition     = contains(["count", "block"], var.waf_mode)
    error_message = "waf_mode must be 'count' or 'block'."
  }
}

variable "waf_log_retention_days" {
  description = "WAFログのCloudWatch Logs保持日数"
  type        = number
  default     = 7
}
