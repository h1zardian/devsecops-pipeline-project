resource "aws_db_subnet_group" "rds" {
  name       = "devsecops-db-subnet-group-${var.environment}"
  subnet_ids = var.subnet_ids

  tags = {
    Environment = var.environment
  }
}

resource "aws_security_group" "rds" {
  name        = "devsecops-rds-sg-${var.environment}"
  description = "Allow PostgreSQL traffic from VPC"
  vpc_id      = var.vpc_id

  ingress {
    description = "PostgreSQL from VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "postgres" {
  identifier             = "devsecops-postgres-${var.environment}"
  allocated_storage      = 20
  max_allocated_storage  = 50
  engine                 = "postgres"
  engine_version         = "15"
  instance_class         = var.environment == "prod" ? "db.t3.medium" : "db.t3.micro"
  db_name                = "hospital_db"
  username               = "postgres"
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.rds.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  multi_az            = var.environment == "prod" ? true : false
  storage_encrypted   = true
  skip_final_snapshot = var.environment == "prod" ? false : true
  deletion_protection = var.environment == "prod" ? true : false

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "random_password" "django_secret_key" {
  length  = 50
  special = false
}

resource "aws_secretsmanager_secret" "django" {
  name                    = "${var.environment}/django"
  description             = "Django application secrets for ${var.environment} environment"
  recovery_window_in_days = var.environment == "prod" ? 7 : 0

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_secretsmanager_secret_version" "django" {
  secret_id = aws_secretsmanager_secret.django.id
  secret_string = jsonencode({
    secret_key  = random_password.django_secret_key.result
    db_password = var.db_password
  })
}

