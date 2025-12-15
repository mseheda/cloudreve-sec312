# RDS's subnet groups decide how we're going to place our db instances
resource "aws_db_subnet_group" "db-subnet" {
  name = "db-subnet"
  tags = merge(var.tags, { Name = "${var.name_prefix}-rds-mysql" })
  # Put db in two private subnets in DB tier
  subnet_ids = [
    aws_subnet.tt-vpc-subnet-private3.id,
    aws_subnet.tt-vpc-subnet-private4.id
  ]
}

# The RDS instance we need
resource "aws_db_instance" "db-back" {
  storage_type = "gp3"
  allocated_storage    = 20
  db_name              = var.db-name
  engine               = "mysql"
  engine_version       = "8.0.44"
  instance_class       = "db.t3.micro"
  username             = var.db-username
  password             = var.db-password
  skip_final_snapshot  = true # Do not take a snapshot before deleting DB

  # DB instance will be created in the VPC associated with the DB subnet group. 
  db_subnet_group_name = aws_db_subnet_group.db-subnet.name

  # Remember it's security group
  vpc_security_group_ids = [
    aws_security_group.sg-db.id
  ]

  multi_az = false
  publicly_accessible = false
}