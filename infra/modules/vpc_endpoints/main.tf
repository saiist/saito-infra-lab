locals {
  ecr_api_service = "com.amazonaws.${var.region}.ecr.api"
  ecr_dkr_service = "com.amazonaws.${var.region}.ecr.dkr"
  logs_service    = "com.amazonaws.${var.region}.logs"
  sm_service      = "com.amazonaws.${var.region}.secretsmanager"
  s3_service      = "com.amazonaws.${var.region}.s3"
}

# Interface Endpoint用 SG：ECSタスクSGから443だけ許可
resource "aws_security_group" "vpce" {
  name   = "${var.project}-${var.env}-vpce-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [var.ecs_sg_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = var.vpc_id
  service_name        = local.ecr_api_service
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.app_subnet_ids
  security_group_ids  = [aws_security_group.vpce.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = var.vpc_id
  service_name        = local.ecr_dkr_service
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.app_subnet_ids
  security_group_ids  = [aws_security_group.vpce.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "logs" {
  vpc_id              = var.vpc_id
  service_name        = local.logs_service
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.app_subnet_ids
  security_group_ids  = [aws_security_group.vpce.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = var.vpc_id
  service_name        = local.sm_service
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.app_subnet_ids
  security_group_ids  = [aws_security_group.vpce.id]
  private_dns_enabled = true
}

# ECRのイメージレイヤ取得はS3を使うので、S3 Gateway endpoint を private RT に関連付ける
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = var.vpc_id
  service_name      = local.s3_service
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [var.private_route_table_id]
}
