terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

data "aws_ami" "linux2" {
  owners      = ["amazon"]
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }
}
provider "github" {
  token = "XXXXXXXXXXXX"
}


resource "github_repository" "myrepo" {
  name       = "bookstore-api-project"
  auto_init  = true
  visibility = "private"
}

resource "github_branch_default" "main" {
  branch     = "main"
  repository = github_repository.myrepo.name
}

variable "files" {
  default = ["bookstore-api.py", "docker-compose.yml", "Dockerfile", "requirements.txt"]

}


resource "github_repository_file" "app_files" {
  for_each            = toset(var.files)
  content             = file(each.value)
  file                = each.value
  repository          = github_repository.myrepo.name
  overwrite_on_create = true
  branch              = "main"
  commit_message      = "app-files added to repo"
}

resource "aws_security_group" "tf-secgrp" {
  name = "tf-secgrp"
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
  ami             = data.aws_ami.linux2.id
  instance_type   = "t2.micro"
  key_name        = "firstkey"
  security_groups = ["tf-secgrp"]
  tags = {
    Name = "Web Server of Bookstore"
  }
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
                mkdir -p /home/ec2-user/bookstore-api
                TOKEN="XXXXXXXXXXXX"
                FOLDER="https://$TOKEN@raw.githubusercontent.com/Nec2005/bookstore-api-project/main/"
                curl -s --create-dirs -o "/home/ec2-user/bookstore-api/app.py" -L "$FOLDER"bookstore-api.py
                curl -s --create-dirs -o "/home/ec2-user/bookstore-api/requirements.txt" -L "$FOLDER"requirements.txt
                curl -s --create-dirs -o "/home/ec2-user/bookstore-api/Dockerfile" -L "$FOLDER"Dockerfile
                curl -s --create-dirs -o "/home/ec2-user/bookstore-api/docker-compose.yml" -L "$FOLDER"docker-compose.yml
                cd /home/ec2-user/bookstore-api
                docker build -t nec2005/bookstoreapi:latest .
                docker-compose up -d
                EOF
    depends_on = [github_repository.myrepo, github_repository_file.app_files]
}

output "webserver" {
  value = "http://${aws_instance.apiserver.public_dns}"

}


