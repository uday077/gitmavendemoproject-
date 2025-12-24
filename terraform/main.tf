provider "aws" {
  region = "ap-south-1"
}

# 1. ECR Repository (Store Room)
resource "aws_ecr_repository" "my_repo" {
  name = "uday-ecr-terraform"  # Naya naam diya taaki conflict na ho
  force_delete = true
}

# 2. IAM Role for CodeBuild (Builder ke liye permission)
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

# CodeBuild ko ECR PowerUser permission dena
resource "aws_iam_role_policy_attachment" "codebuild_attach" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

# CodeBuild ko Logs ki permission dena (Zaruri hai)
resource "aws_iam_role_policy_attachment" "codebuild_logs" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

# 3. CodeBuild Project (The Factory)
resource "aws_codebuild_project" "my_project" {
  name          = "terraform-demo-project"
  service_role  = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true # Docker chalane ke liye zaruri hai
  }

  source {
    type            = "GITHUB"
    location        = "https://github.com/uday077/gitmavendemoproject.git" # APNA URL YAHAN DALNA
    git_clone_depth = 1
  }
}

# 4. IAM Role for EC2 (Server ke liye permission)
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

# EC2 ko ECR ReadOnly permission dena
resource "aws_iam_role_policy_attachment" "ec2_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Instance Profile (Role ko EC2 se jodne ke liye)
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "terraform-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# 5. Security Group (Firewall)
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
  
  # Custom TCP 8080 (Agar directly access karna ho)
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

# 6. EC2 Instance (Server with Auto-Install Script)
resource "aws_instance" "app_server" {
  ami           = "ami-0dee22c13ea7a9a67" # Ubuntu 24.04 (ap-south-1 ke liye)
  instance_type = "t2.micro"
  key_name      = "my-key" # APNI KEY KA NAAM YAHAN LIKHEIN (Jo AWS me pehle se hai)
  
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  # Ye wahi script hai jo humne 'User Data' me dali thi
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

# 7. Output (IP Address print karega)
output "server_public_ip" {
  value = aws_instance.app_server.public_ip
}
