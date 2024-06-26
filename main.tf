terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

# Create a VPC
resource "aws_vpc" "example_vpc" {
  cidr_block = "10.0.0.0/16"
}

# Create a public subnet within the VPC
resource "aws_subnet" "example_subnet" {
  vpc_id            = aws_vpc.example_vpc.id
  cidr_block        = "10.0.1.0/24" # Adjust the CIDR block as needed for your network
  availability_zone = "us-east-1a"

  # Tag the subnet
  tags = {
    Name = "example-subnet"
  }
}

# Create an internet gateway and attach it to the VPC
resource "aws_internet_gateway" "example_igw" {
  vpc_id = aws_vpc.example_vpc.id

  # Tag the internet gateway
  tags = {
    Name = "example-igw"
  }
}

# Create a route table and route for the public subnet
resource "aws_route_table" "example_route_table" {
  vpc_id = aws_vpc.example_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.example_igw.id
  }

  # Tag the route table
  tags = {
    Name = "example-route-table"
  }
}

# Associate the route table with the public subnet
resource "aws_route_table_association" "example_subnet_association" {
  subnet_id      = aws_subnet.example_subnet.id
  route_table_id = aws_route_table.example_route_table.id
}

# Create a minimal security group
resource "aws_security_group" "inbound_ssh_http" {
  name        = "inbound-ssh-http"
  description = "Allow SSH and HTTP inbound traffic"

  vpc_id = aws_vpc.example_vpc.id # Replace with your VPC ID

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow SSH from anywhere
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow HTTP from anywhere
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-ebs"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_instance" "main" {
  ami               = data.aws_ami.ubuntu.id
  availability_zone = "us-east-1a"
  instance_type     = "t3.small"
  subnet_id         = aws_subnet.example_subnet.id

  key_name = aws_key_pair.login.key_name

  vpc_security_group_ids = [
    aws_security_group.inbound_ssh_http.id
  ]
  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install git -y
              sudo amazon-linux-extras install docker git -y
              sudo service docker start
              sudo usermod -a -G docker ec2-user
              sudo systemctl enable docker
              sudo curl -L https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
              sudo chmod +x /usr/local/bin/docker-compose
              EOF

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("~/.ssh/id_rsa") # Change this to the path of your private key
    host        = self.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y",
      "sudo amazon-linux-extras install docker -y",
      "sudo service docker start",
      "sudo usermod -a -G docker ec2-user",
      "sudo systemctl enable docker"
    ]
  }

  user_data_replace_on_change = true

  associate_public_ip_address = true
}

resource "aws_key_pair" "login" {
  key_name   = "login-key"
  public_key = file("~/.ssh/id_rsa.pub")
}
