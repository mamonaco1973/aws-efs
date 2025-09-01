# -------------------------------------------------------------------
# Security Group for EFS
# -------------------------------------------------------------------
resource "aws_security_group" "efs_sg" {
  name        = "efs-sg"
  description = "Allow NFS traffic"
  vpc_id      =  aws_vpc.ad-vpc.id

  ingress {
    description = "Allow NFS"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]   # ⚠️ Insecure — restrict in production
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "efs-sg"
  }
}

# -------------------------------------------------------------------
# EFS File System
# -------------------------------------------------------------------
resource "aws_efs_file_system" "efs" {
  creation_token = "mcloud-efs"
  encrypted      = true

  tags = {
    Name = "mcloud-efs"
  }
}

# Use existing subnets in that VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [aws_vpc.ad-vpc.id]
  }
}

# -------------------------------------------------------------------
# Mount Targets in each subnet
# -------------------------------------------------------------------
resource "aws_efs_mount_target" "efs_mnt" {
  for_each       = toset(data.aws_subnets.default.ids)
  file_system_id = aws_efs_file_system.efs.id
  subnet_id      = each.value
  security_groups = [
    aws_security_group.efs_sg.id
  ]
}
