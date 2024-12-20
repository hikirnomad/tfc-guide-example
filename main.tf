terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 3.0"
    }
  }
}

# Vault Provider Configuration
provider "vault" {
  address = "http://127.0.0.1:8200"
}

# Fetch AWS credentials from Vault
data "vault_kv_secret_v2" "aws_creds" {
  mount = "secret"
  name  = "aws"
}

# AWS Provider Configuration
provider "aws" {
  region     = "us-east-1"
  access_key = data.vault_kv_secret_v2.aws_creds.data["AWS_ACCESS_KEY_ID"]
  secret_key = data.vault_kv_secret_v2.aws_creds.data["AWS_SECRET_ACCESS_KEY"]
}

# Generate an RSA key of size 4096 bits
resource "tls_private_key" "rsa_4096" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Store the RSA private key locally
resource "local_file" "private_key" {
  content  = tls_private_key.rsa_4096.private_key_pem
  filename = "${var.key_name}.pem"
}

# Define the AWS Key Pair
resource "aws_key_pair" "key_pair" {
  key_name   = var.key_name
  public_key = tls_private_key.rsa_4096.public_key_openssh
}

# Variable for Key Name
variable "key_name" {
  default = "my-key"
}

# Create an EC2 instance
resource "aws_instance" "public_instance" {
  ami           = "ami-0e2c8caa4b6378d8c" # Example Amazon Linux 2 AMI
  instance_type = "t2.micro"
  key_name      = aws_key_pair.key_pair.key_name

  vpc_security_group_ids = [
    aws_security_group.http.id,
    aws_security_group.ssh.id
  ]

  tags = {
    Name = "public_instance"
  }
}

# Security Group for HTTP
resource "aws_security_group" "http" {
  name        = "allow_http"
  description = "Allow HTTP inbound traffic"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group for SSH
resource "aws_security_group" "ssh" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Replace with your IP range for better security
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
