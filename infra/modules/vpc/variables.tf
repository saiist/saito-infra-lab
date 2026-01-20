variable "project" { type = string }
variable "env" { type = string }

variable "vpc_cidr" { type = string }
variable "azs" { type = list(string) }

variable "public_subnet_cidrs" { type = list(string) }
variable "app_subnet_cidrs" { type = list(string) }
variable "db_subnet_cidrs" { type = list(string) }

variable "enable_nat_gateway" {
  type    = bool
  default = true
}
variable "single_nat_gateway" {
  type    = bool
  default = true
}
