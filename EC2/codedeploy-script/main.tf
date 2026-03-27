terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"  # Change as needed
}

module "ec2" {
  source = "./child-module/ec2"

  ami                = "ami-0ec10929233384c7f"  # Update AMI ID
  instance_type      = "t3.micro"
  key_name           = "project-automation"  # Replace with your key pair
  security_group_ids = ["sg-0b2ab1796913f81fb"]  # Replace with actual SG IDs
  subnet_id          = "subnet-07ac29c7f89da4893"  # Replace with actual subnet ID
  tags = {
    Environment = "dev"
  }
}

module "codedeploy" {
  source = "./child-module/codedeploy"

  application_name     = "my-app"
  deployment_group_name = "my-deployment-group"
  ec2_tag_key          = "Name"
  ec2_tag_value        = "CodeDeploy-EC2"
}