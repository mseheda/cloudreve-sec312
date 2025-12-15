# Three security groups (SG)

# SG for the frontend tier
#   Allow traffics from the internet
resource "aws_security_group" "sg-front" {
  name = "front-sg"
  description = "Allow connection to the frontend tier"
  tags = merge(var.tags, { Name = "${var.name_prefix}-sg-front-alb-public" })
  vpc_id = aws_vpc.tt-vpc.id


  # Allow HTTP connection on Port 80 from anywhere
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP connection"
  }

  # Allow SSH on port 22 from anywhere
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow SSH connection"
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group#recreating-a-security-group
  # Need this option to avoid the sticky problem. 
  #   In AWS, you cannot delete an SG having resources associated with it. 
  #   But in Terraform, simple changes such as adjusting the SG name result in 
  #   deleting and re-creating the security group. You get errors if there are resources associated
  #   to the SG you want to work on.
  # 
  #   Use the create_before_destroy option to avoid this problem.
  lifecycle {
    create_before_destroy = true
  }
}

# SG for the backend tier
#   Allow traffics from the frontend tier
resource "aws_security_group" "sg-back" {
  name = "back-sg"
  description = "Allow connection from the frontend tier"
  tags = merge(var.tags, { Name = "${var.name_prefix}-sg-back-app-private" })
  vpc_id = aws_vpc.tt-vpc.id

  # Allow HTTP connection on Port 80 from frontend tier
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    description = "Allow HTTP connection"
    security_groups = [aws_security_group.sg-front.id]
  }

  # Allow SSH connection on Port 22 from backend tier
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    description = "Allow SSH connection"
    security_groups = [aws_security_group.sg-front.id]
  }

  # Need this so healthcheck from backend's application load balancer and target group works
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    description = "Allow health check"
    self = true
  }

  # Allow ping from frontend tier
  ingress {
    from_port = 8
    to_port = 0
    protocol = "icmp"
    description = "Allow icmp"
    security_groups = [aws_security_group.sg-front.id]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

# SG for the database (db) tier
#   Allow traffics from the backend tier
resource "aws_security_group" "sg-db" {
  name = "db-sg"
  description = "Allow connection from the backend tier"
  tags = merge(var.tags, { Name = "${var.name_prefix}-sg-db-mysql-private" })
  vpc_id = aws_vpc.tt-vpc.id

  # Allow backend tier to connect to SQL server
  ingress {
    from_port = 3306
    to_port = 3306
    protocol = "tcp"
    description = "Allow connection to SQL"
    security_groups = [aws_security_group.sg-back.id]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}