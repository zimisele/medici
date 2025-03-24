resource "aws_vpc" "main" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"
  enable_dns_support = "true"
  enable_dns_hostnames = true

  tags = {
	Name = "MyVPC"
  }
}
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
	Name = "MyinternatGW"
  }
}
resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "eu-west-1a"
  map_public_ip_on_launch = true
  tags = {
	Name = "PublicSubnet"
  }
}
resource "aws_eip" "natIP" {
  vpc = true
  tags = {
	Name = "nat-eip"
  }
}
resource "aws_nat_gateway" "natgw" {
  allocation_id = aws_eip.natIP.id
  subnet_id     = aws_subnet.public.id
  tags = {
	Name = "gw NAT"
  }
  depends_on = [aws_internet_gateway.gw]
}
resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "eu-west-1b"
  tags = {
	Name = "PrivateSubnet"
  }
}
# Public Route Table
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.main.id
  tags = {
	Name = "public_route_table"
  }
}
# Private Route Table 
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.main.id
  tags = {
	Name = "private_route_table"
  }
}
resource "aws_route" "internet_route" {
  route_table_id         = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}
resource "aws_route" "internet_route_private" {
  route_table_id         = aws_route_table.private_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_nat_gateway.natgw.id
}
# Public Subnet Association
resource "aws_route_table_association" "public_association" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_route_table.id
}

# Private Subnet Association
resource "aws_route_table_association" "private_association" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private_route_table.id
}

#here I'm creating ec2 instance
#this is the ec2 security group
resource "aws_security_group" "ec2_sg" {
  vpc_id = aws_vpc.main.id
  name        = "ec2_sg"
  description = "Allow inbound traffic from RDS and outbound traffic"
  egress {
	from_port   = 0
	to_port     = 0
	protocol    = "-1"
	cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
	from_port   = 3306
	to_port     = 3306
	protocol    = "tcp"
	cidr_blocks = ["10.0.0.0/16"]
  }
   ingress {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"] 
  }
}
# this security group is for rds
resource "aws_security_group" "rds_sg" {
  vpc_id = aws_vpc.main.id
  name        = "rds_sg"
  description = "Allow inbound traffic from EC2"
  egress {
	from_port   = 0
	to_port     = 0
	protocol    = "-1"
	cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
	from_port   = 3306
	to_port     = 3306
	protocol    = "tcp"
	security_groups = [aws_security_group.ec2_sg.id]
  }
   ingress {
       from_port   = 80
       to_port     = 80
       protocol    = "tcp"
       cidr_blocks = ["0.0.0.0/0"]  
  }

  ingress {
     from_port   = 443
     to_port     = 443
     protocol    = "tcp"
     cidr_blocks = ["0.0.0.0/0"]  # Allow HTTPS from anywhere
  }
}

#here is my ec2 instance
resource "aws_instance" "ec2_instance" {
  ami           = "ami-0df368112825f8d8f"
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.public.id
  key_name = "demo"
  vpc_security_group_ids  = [aws_security_group.ec2_sg.id]
  tags = {
	Name = "EC2 Instance"
  }
}
#here is my RDS
resource "aws_db_instance" "rds_instance" {
  identifier        = "my-rds-instance"
  engine            = "mysql"
  engine_version    = "8.0"
  instance_class    = "db.c6gd.medium"
  allocated_storage = 20
  db_subnet_group_name = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  username          = "admin"
  password          = "87654321" 
  skip_final_snapshot = true
  publicly_accessible = false
  tags = {
	Name = "RDS Instance"
  }
}

resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "my-db-subnet-group"
  subnet_ids = [aws_subnet.private.id,aws_subnet.public.id]

  tags = {
	Name = "My DB Subnet Group"
  }
}
# here is my ecr
resource "aws_ecr_repository" "myECR" {
  name                 = "medeci"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
	scan_on_push = true
  }
}
