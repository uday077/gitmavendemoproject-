provider "aws" {
  region = "ap-south-1"
}

# --- 1. ECR Repository ---
resource "aws_ecr_repository" "my_repo" {
  name         = "uday-ecr"
  force_delete = true
}

# --- 2. IAM Role for CodeBuild ---
resource "aws_iam_role" "codebuild_role" {
  name = "terraform-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "codebuild.amazonaws.com" }
    }]
  })
}

# Permissions
resource "aws_iam_role_policy_attachment" "codebuild_ecr_attach" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

resource "aws_iam_role_policy_attachment" "codebuild_logs_attach" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

# --- 3. CodeBuild Project ---
resource "aws_codebuild_project" "my_project" {
  name          = "terraform-demo-project"
  service_role  = aws_iam_role.codebuild_role.arn
  build_timeout = "5"

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true
  }

  source {
    type            = "GITHUB"
    location        = "https://github.com/uday077/terraformcodebuildproject.git"
    git_clone_depth = 1
    
    # 🔥 CRITICAL FIX: Isse Access Denied error nahi aayega
    report_build_status = false
    
    buildspec = "buildspec.yml"
  }
}

# --- 4. IAM Role for EC2 ---
resource "aws_iam_role" "ec2_role" {
  name = "terraform-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_ecr_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "terraform-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# --- 5. Security Group ---
resource "aws_security_group" "web_sg" {
  name        = "terraform-web-sg"
  description = "Allow HTTP and SSH"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 8080
    to_port     = 8080
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

# --- 6. EC2 Instance ---
resource "aws_instance" "app_server" {
  ami           = "ami-0dee22c13ea7a9a67" # Ubuntu (ap-south-1)
  instance_type = "t3.micro"              # Fix: t3.micro for free tier
  key_name      = "uday"                  # Fix: Your key name

  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              apt update
              apt install docker.io awscli -y
              systemctl start docker
              systemctl enable docker
              usermod -aG docker ubuntu
              EOF

  tags = {
    Name = "Terraform-Docker-Server"
  }
}

# --- 7. Output ---
output "server_ip" {
  value = aws_instance.app_server.public_ip
}
output "ecr_repo_url" {
  value = aws_ecr_repository.my_repo.repository_url
}
