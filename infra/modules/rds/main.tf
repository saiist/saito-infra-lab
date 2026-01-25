resource "aws_db_subnet_group" "this" {
  name       = "${var.project}-${var.env}-dbsubnet"
  subnet_ids = var.db_subnet_ids
}

resource "random_password" "db" {
  length           = 24
  special          = true
  override_special = "!#$%&()*+-.:;<=>?[]^_{|}~"
}

resource "aws_secretsmanager_secret" "db" {
  name = "${var.project}/${var.env}/db"

  # 学習用なのでゴミ箱に残さないようにする
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id

  secret_string = jsonencode({
    host     = aws_db_instance.this.address
    port     = aws_db_instance.this.port
    dbname   = var.db_name
    username = var.db_username
    password = random_password.db.result
  })
}

# パラメータグループ（まずは空でOK。force_ssl等は後で足す）
resource "aws_db_parameter_group" "this" {
  name   = "${var.project}-${var.env}-pg16"
  family = "postgres16"
}

resource "aws_db_instance" "this" {
  identifier = "${var.project}-${var.env}-pg"

  engine         = "postgres"
  engine_version = "16"

  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.rds_sg_id]

  multi_az            = false
  publicly_accessible = false
  storage_encrypted   = true

  backup_retention_period = 3
  skip_final_snapshot     = true
  deletion_protection     = false
  apply_immediately       = true

  parameter_group_name = aws_db_parameter_group.this.name
}
