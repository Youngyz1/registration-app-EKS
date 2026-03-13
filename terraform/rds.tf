resource "aws_db_subnet_group" "main" {
  name       = "${var.cluster_name}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "${var.cluster_name}-db-subnet-group"
  }
}

resource "aws_security_group" "rds" {
  name        = "${var.cluster_name}-rds-sg"
  description = "RDS security group - allows only EKS nodes on 5432"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_cluster.id]
    description     = "PostgreSQL from EKS cluster SG"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-rds-sg"
  }
}

resource "aws_db_instance" "main" {
  identifier     = "${var.cluster_name}-db"
  engine         = "postgres"
  engine_version = "16"

  # Bumped from db.t3.micro - micro will bottleneck
  # with DATABASE_POOL_SIZE=20 in the backend config
  instance_class    = "db.t3.small"
  allocated_storage = 20
  storage_type      = "gp2"

  db_name  = "registrationdb"
  username = "postgres"
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  # High Availability
  multi_az = true # Standby replica in second AZ

  # Data Protection
  deletion_protection       = true  # Must set to false before terraform destroy
  skip_final_snapshot       = false # Creates a snapshot before deletion
  final_snapshot_identifier = "${var.cluster_name}-db-final-snapshot"
  backup_retention_period   = 7     # 7 days of automated backups
  backup_window             = "03:00-04:00" # UTC - low traffic window

  # Maintenance
  maintenance_window         = "Mon:04:00-Mon:05:00"
  auto_minor_version_upgrade = true

  publicly_accessible = false

  tags = {
    Name = "${var.cluster_name}-db"
  }
}

# Allow EKS nodes to connect to RDS
resource "aws_security_group_rule" "eks_to_rds" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  security_group_id        = aws_security_group.rds.id
  description              = "Allow EKS nodes to connect to RDS PostgreSQL"
}