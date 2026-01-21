variable "project" { type = string }
variable "env" { type = string }

variable "db_subnet_ids" { type = list(string) }
variable "rds_sg_id" { type = string }

variable "db_name" {
  type    = string
  default = "app"
}

variable "db_username" {
  type    = string
  default = "appuser"
}

# dev用の軽量設定
variable "instance_class" {
  type    = string
  default = "db.t4g.micro" # コスト優先。amdでもOK
}

variable "allocated_storage" {
  type    = number
  default = 20
}
