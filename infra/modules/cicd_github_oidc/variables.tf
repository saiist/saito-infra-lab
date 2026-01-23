variable "project" { type = string }
variable "env" { type = string }
variable "aws_region" { type = string }

variable "github_owner" { type = string }
variable "github_repo" { type = string }
variable "github_ref" { type = string } # refs/heads/main

variable "ecr_repository_arn" { type = string } # arn:aws:ecr:...:repository/xxx

variable "ecs_service_arn" { type = string } # arn:aws:ecs:...:service/cluster/service

variable "ecs_task_execution_role_arn" { type = string } # arn:aws:iam::...:role/xxx
variable "ecs_task_role_arn" { type = string }           # arn:aws:iam::...:role/xxx
