provider "aws" {
  region = "us-east-1"
}

# Prod VPC (10.100.0.0/16)
resource "aws_vpc" "prod_vpc" {
  cidr_block = "10.100.0.0/16"
}

# Dev VPC
resource "aws_vpc" "dev_vpc" {
  cidr_block = "10.101.0.0/16"
}

# Public Subnet for Prod VPC in AZ-A
resource "aws_subnet" "prod_public_subnet" {
  vpc_id            = aws_vpc.prod_vpc.id
  cidr_block        = "10.100.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true
}

# Private Subnet for Prod VPC in AZ-A
resource "aws_subnet" "prod_private_subnet" {
  vpc_id            = aws_vpc.prod_vpc.id
  cidr_block        = "10.100.2.0/24"
  availability_zone = "us-east-1a"
}

# Private Subnet for Dev VPC in AZ-B
resource "aws_subnet" "dev_private_subnet" {
  vpc_id            = aws_vpc.dev_vpc.id
  cidr_block        = "10.101.2.0/24"
  availability_zone = "us-east-1b"
}

# Internet Gateway for Prod VPC
resource "aws_internet_gateway" "prod_igw" {
  vpc_id = aws_vpc.prod_vpc.id
}

# Route table for public subnet in Prod VPC
resource "aws_route_table" "prod_public_route_table" {
  vpc_id = aws_vpc.prod_vpc.id
}

# Route for public subnet to send traffic to the internet via IGW
resource "aws_route" "prod_public_route" {
  route_table_id         = aws_route_table.prod_public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.prod_igw.id
}

# Associate the route table to the public subnet
resource "aws_route_table_association" "prod_public_route_table_association" {
  subnet_id      = aws_subnet.prod_public_subnet.id
  route_table_id = aws_route_table.prod_public_route_table.id
}

# Transit Gateway (TGW)
resource "aws_ec2_transit_gateway" "tgw" {
  description = "My Transit Gateway"
}

# TGW attachment for Prod VPC (only attach the private subnet)
resource "aws_ec2_transit_gateway_vpc_attachment" "prod_tgw_attach" {
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  vpc_id             = aws_vpc.prod_vpc.id
  subnet_ids         = [aws_subnet.prod_private_subnet.id]
  depends_on         = [aws_ec2_transit_gateway.tgw]
}

# TGW attachment for Dev VPC (private subnet)
resource "aws_ec2_transit_gateway_vpc_attachment" "dev_tgw_attach" {
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  vpc_id             = aws_vpc.dev_vpc.id
  subnet_ids         = [aws_subnet.dev_private_subnet.id]
  depends_on         = [aws_ec2_transit_gateway.tgw]
}

# Prod VPC private route table
resource "aws_route_table" "prod_private_route_table" {
  vpc_id = aws_vpc.prod_vpc.id
}

# Route for Prod VPC private subnet to send traffic to Dev VPC via TGW
resource "aws_route" "prod_private_route_tgw" {
  route_table_id         = aws_route_table.prod_private_route_table.id
  destination_cidr_block = "10.101.0.0/16"
  transit_gateway_id     = aws_ec2_transit_gateway.tgw.id
  depends_on             = [aws_ec2_transit_gateway_vpc_attachment.prod_tgw_attach]
}

# Route table with the private subnet in Prod VPC
resource "aws_route_table_association" "prod_private_route_table_association" {
  subnet_id      = aws_subnet.prod_private_subnet.id
  route_table_id = aws_route_table.prod_private_route_table.id
}

# Dev VPC route table
resource "aws_route_table" "dev_private_route_table" {
  vpc_id = aws_vpc.dev_vpc.id
}

# Route for Dev VPC to send traffic to Prod VPC via TGW
resource "aws_route" "dev_private_route_tgw" {
  route_table_id         = aws_route_table.dev_private_route_table.id
  destination_cidr_block = "10.100.0.0/16"
  transit_gateway_id     = aws_ec2_transit_gateway.tgw.id
  depends_on             = [aws_ec2_transit_gateway_vpc_attachment.dev_tgw_attach]
}

# Route table with the private subnet in Dev VPC
resource "aws_route_table_association" "dev_private_route_table_association" {
  subnet_id      = aws_subnet.dev_private_subnet.id
  route_table_id = aws_route_table.dev_private_route_table.id
}
