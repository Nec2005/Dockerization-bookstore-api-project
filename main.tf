terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "3.72.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

data "aws_ami" "linux2" {
  owners = ["amazon"]
  most_recent = 
  filter {
      name = "name"
      values = ["amzn2-ami-hvm*"]
  }
}

resource "aws_security_group" "tf-secgrp" {
  name = "allow_https_ssh"
  tags = {
    Name = "allow_ssh_https"
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
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
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

resource "aws_instance" "apiserver" {
    ami = data.aws_ami.linux2
    instance_type = "t2.micro"
    key_name = "firstkey"
    security_groups = ["${aws_security_group.tf-secgrp}"]
    user_data = <<-EOF
                #!/bin/bash
                yum update -y
                yum install git -y
                amazon-linux-extras install docker -y
                systemctl start docker
                systemctl enable docker
                usermod -a -G docker ec2-user
                curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" \
                -o /usr/local/bin/docker-compose
                chmod +x /usr/local/bin/docker-compose
                git clone https://github.com/Nec2005/Dockerization-bookstore-api-project.git
                cd /home/ec2-user/Dockerization-bookstore-api-project
                docker-compose up
                EOF

    tags = {
        Name = "apiserver"
    }
}