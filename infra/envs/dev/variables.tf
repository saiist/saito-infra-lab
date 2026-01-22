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

variable "vpc_cidr" {
  type    = string
  default = "10.10.0.0/16"
}

# まずは2AZ固定でOK（東京）
variable "azs" {
  type    = list(string)
  default = ["ap-northeast-1a", "ap-northeast-1c"]
}

# サブネットは /24 を6個（public×2, app×2, db×2）
variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.10.0.0/24", "10.10.1.0/24"]
}
variable "app_subnet_cidrs" {
  type    = list(string)
  default = ["10.10.10.0/24", "10.10.11.0/24"]
}
variable "db_subnet_cidrs" {
  type    = list(string)
  default = ["10.10.20.0/24", "10.10.21.0/24"]
}

variable "enable_nat_gateway" {
  type = bool
}

variable "single_nat_gateway" {
  type = bool
}

variable "domain_name" {
  type    = string
  default = "saito-infra-lab.click"
}

variable "api_record_name" {
  type    = string
  default = "api.dev"
}

variable "container_image" {
  type = string
  # 例: 9770....amazonaws.com/saito-infra-lab-dev-app:dev
}
