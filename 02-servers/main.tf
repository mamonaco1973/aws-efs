# Define the AWS provider and set the region to us-east-1 (N. Virginia)
# Modify this if your deployment requires a different AWS region
provider "aws" {
  region = "us-east-1"
}

# Fetch AWS Secrets Manager secrets for the AD admin user
# These secrets store AD credentials for authentication purposes


data "aws_secretsmanager_secret" "admin_secret" {
  name = "admin_ad_credentials" # Secret name for the admin user in AWS Secrets Manager
}

data "aws_subnet" "vm_subnet_1" {
  filter {
    name   = "tag:Name"      # Match based on the 'Name' tag
    values = ["vm-subnet-1"] # Look for a subnet tagged as "vm-subnet-1"
  }
}

data "aws_subnet" "ad_subnet" {
  filter {
    name   = "tag:Name"      # Match based on the 'Name' tag
    values = ["ad-subnet"] # Look for a subnet tagged as "ad-subnet"
  }
}

# Retrieve details of the AWS VPC where Active Directory components will be deployed
# Uses a tag-based filter to locate the correct VPC

data "aws_vpc" "ad_vpc" {
  filter {
    name   = "tag:Name"
    values = ["ad-vpc"] # Look for a VPC tagged as "ad-vpc"
  }
}

# Fetch the most recent Windows Server 2022 AMI provided by AWS
# This ensures we deploy the latest Windows Server OS image

data "aws_ami" "windows_ami" {
  most_recent = true       # Fetch the latest Windows Server AMI
  owners      = ["amazon"] # AWS official account for Windows AMIs

  filter {
    name   = "name"                                      # Filter AMIs by name pattern
    values = ["Windows_Server-2022-English-Full-Base-*"] # Match Windows Server 2022 AMI
  }
}

