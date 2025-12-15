# Provision these:
#   VPC, Subnet, Route Table, Internet Gateway, Network Address Translation (NAT) Gateway
# Internet gateway is not free; charges apply based on hourly usage and data usage. Remember to put it down.

# VPC with CIDR=10.0.0.0/16
resource "aws_vpc" "tt-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = merge(var.tags, { Name = "${var.name_prefix}-vpc" })
}

# Public Subnet * 2 for the frontend-tier with CIDRs
#   10.0.1.0/24 in az1
#   10.0.2.0/24 in az2
resource "aws_subnet" "tt-vpc-subnet-public1" {
  vpc_id = aws_vpc.tt-vpc.id
  cidr_block = "10.0.1.0/24"
  tags = merge(var.tags, { Name = "${var.name_prefix}-subnet-public-az1-10.0.1.0-24" })
  availability_zone = var.az1
  map_public_ip_on_launch = true # Assign public IPs for instances in this subnet
}

resource "aws_subnet" "tt-vpc-subnet-public2" {
  vpc_id = aws_vpc.tt-vpc.id
  cidr_block = "10.0.2.0/24"
  tags = merge(var.tags, { Name = "${var.name_prefix}-subnet-public-az2-10.0.2.0-24" })
  availability_zone = var.az2
  map_public_ip_on_launch = true
}

# Private  Subnet * 2 for the backend-tier with CIDRs
#   10.0.3.0/24 in az1
#   10.0.4.0/24 in az2
resource "aws_subnet" "tt-vpc-subnet-private1" {
  vpc_id = aws_vpc.tt-vpc.id
  cidr_block = "10.0.3.0/24"
  tags = merge(var.tags, { Name = "${var.name_prefix}-subnet-private-app-az1-10.0.3.0-24" })
  availability_zone = var.az1
  map_public_ip_on_launch = false # Do not assign public IPS to instances in this subnet
}

resource "aws_subnet" "tt-vpc-subnet-private2" {
  vpc_id = aws_vpc.tt-vpc.id
  cidr_block = "10.0.4.0/24"
  tags = merge(var.tags, { Name = "${var.name_prefix}-subnet-private-app-az2-10.0.4.0-24" })
  availability_zone = var.az2
  map_public_ip_on_launch = false
}

# Private  Subnet * 2 for the db-tier with CIDRs
#   10.0.5.0/24 in az1
#   10.0.6.0/24 in az2
resource "aws_subnet" "tt-vpc-subnet-private3" {
  vpc_id = aws_vpc.tt-vpc.id
  cidr_block = "10.0.5.0/24"
  tags = merge(var.tags, { Name = "${var.name_prefix}-subnet-private-db-az1-10.0.5.0-24" })
  availability_zone = var.az1
  map_public_ip_on_launch = false
}

resource "aws_subnet" "tt-vpc-subnet-private4" {
  vpc_id = aws_vpc.tt-vpc.id
  cidr_block = "10.0.6.0/24"
  tags = merge(var.tags, { Name = "${var.name_prefix}-subnet-private-db-az2-10.0.6.0-24" })
  availability_zone = var.az2
  map_public_ip_on_launch = false
}

# Internet Gateway
#   Allow instances in public subnets to connect to the internet
# Internet gateway is not free; charges apply based on hourly usage and data usage. Remember to put it down.
resource "aws_internet_gateway" "tt-vpc-internet-gateway" {
  vpc_id = aws_vpc.tt-vpc.id
  tags = merge(var.tags, { Name = "${var.name_prefix}-igw" })
}

# Network Address Translation (NAT) Gateway
#   Allow instances in private subnets to connect to the internet
resource "aws_eip" "tt-vpc-nat-gateway-eip" {
  domain           = "vpc"
  tags = merge(var.tags, { Name = "${var.name_prefix}-eip-nat" })
}

resource "aws_nat_gateway" "tt-vpc-nat-gateway" {
  subnet_id = aws_subnet.tt-vpc-subnet-public2.id
  allocation_id = aws_eip.tt-vpc-nat-gateway-eip.id
  depends_on = [aws_internet_gateway.tt-vpc-internet-gateway]
  tags = merge(var.tags, { Name = "${var.name_prefix}-natgw-public-az2" })
}

# Public Route table
#   A route table contains rules to direct traffics coming out of public subnets
resource "aws_route_table" "tt-vpc-route-table-public" {
  vpc_id = aws_vpc.tt-vpc.id
  tags = merge(var.tags, { Name = "${var.name_prefix}-rt-public" })

  # Direct traffics to internet gateway
  # can't curl google.com without this rule
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.tt-vpc-internet-gateway.id
  }

  # Adopt the default route created by AWS
  route {
    cidr_block = aws_vpc.tt-vpc.cidr_block
    gateway_id = "local"
  }
}

#   Set the public route table as the main route table.
#   Subnets in this VPC not explicitly assigned to a route table are automatically associated with the main route table
resource "aws_main_route_table_association" "tt-vpc-main-route-table" {
  vpc_id = aws_vpc.tt-vpc.id
  route_table_id = aws_route_table.tt-vpc-route-table-public.id
}

#   Link two public subnets to the public route table
resource "aws_route_table_association" "tt-vpc-route-table-public-subnet-1" {
  subnet_id = aws_subnet.tt-vpc-subnet-public1.id
  route_table_id = aws_route_table.tt-vpc-route-table-public.id
}

resource "aws_route_table_association" "tt-vpc-route-table-public-subnet-2" {
  subnet_id = aws_subnet.tt-vpc-subnet-public2.id
  route_table_id = aws_route_table.tt-vpc-route-table-public.id
}


# Private Route table
#   rules to direct traffics coming out of private subnets
resource "aws_route_table" "tt-vpc-route-table-private" {
  vpc_id = aws_vpc.tt-vpc.id
  tags = merge(var.tags, { Name = "${var.name_prefix}-rt-private" })

  # direct traffics to NAT Gateway
  # can't curl google.com without this rule
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.tt-vpc-nat-gateway.id
  }

  # Adopt the default route created by AWS
  route {
    cidr_block = aws_vpc.tt-vpc.cidr_block
    gateway_id = "local"
  }
}

#   Link four private subnets to the public route table
resource "aws_route_table_association" "tt-vpc-route-table-private-subnet-1" {
  subnet_id = aws_subnet.tt-vpc-subnet-private1.id
  route_table_id = aws_route_table.tt-vpc-route-table-private.id
}

resource "aws_route_table_association" "tt-vpc-route-table-private-subnet-2" {
  subnet_id = aws_subnet.tt-vpc-subnet-private2.id
  route_table_id = aws_route_table.tt-vpc-route-table-private.id
}

resource "aws_route_table_association" "tt-vpc-route-table-private-subnet-3" {
  subnet_id = aws_subnet.tt-vpc-subnet-private3.id
  route_table_id = aws_route_table.tt-vpc-route-table-private.id
}

resource "aws_route_table_association" "tt-vpc-route-table-private-subnet-4" {
  subnet_id = aws_subnet.tt-vpc-subnet-private4.id
  route_table_id = aws_route_table.tt-vpc-route-table-private.id
}
