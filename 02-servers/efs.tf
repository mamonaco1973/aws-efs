# ===================================================================
# SECURITY GROUP: Allow NFS access for EFS
# -------------------------------------------------------------------
# This security group is dedicated to the Amazon EFS file system.
# It allows inbound NFS traffic (TCP/2049) so that EC2 instances
# in the same VPC can mount and use the EFS file system.
#
# NOTE: The current ingress rule opens NFS to the entire Internet
# (0.0.0.0/0). This is acceptable for lab/demo purposes but is NOT
# recommended for production. In production, restrict to trusted
# security groups or CIDR ranges (e.g., your VPC subnets).
# ===================================================================
resource "aws_security_group" "efs_sg" {
  name        = "efs-sg"
  description = "Security group allowing NFS traffic to EFS"
  vpc_id      = data.aws_vpc.ad_vpc.id

  ingress {
    description = "Allow inbound NFS traffic"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Demo only — restrict in production
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "efs-sg"
  }
}

# ===================================================================
# EFS FILE SYSTEM: Managed NFS storage
# -------------------------------------------------------------------
# Creates a new Amazon EFS file system. By default, this is
# accessible only within the VPC via mount targets (see below).
#
# - creation_token: Ensures idempotency; unique per file system.
# - encrypted: Enables at-rest encryption for security.
# ===================================================================
resource "aws_efs_file_system" "efs" {
  creation_token = "mcloud-efs"
  encrypted      = true

  tags = {
    Name = "mcloud-efs"
  }
}

# ===================================================================
# EFS MOUNT TARGETS: Connect EFS to a subnet
# -------------------------------------------------------------------
# Creates a mount target for the EFS file system inside the
# "ad-subnet". A mount target is required in each Availability
# Zone where you want EC2 instances to access the file system.
#
# If you need multi-AZ resilience, create one mount target
# per AZ (not per subnet). Each AZ supports exactly one mount
# target for a given EFS file system.
# ===================================================================
resource "aws_efs_mount_target" "efs_mnt_1" {
  file_system_id  = aws_efs_file_system.efs.id
  subnet_id       = data.aws_subnet.vm_subnet_1.id # Reference your specific subnet
  security_groups = [aws_security_group.efs_sg.id]
}

resource "aws_efs_mount_target" "efs_mnt_2" {
  file_system_id  = aws_efs_file_system.efs.id
  subnet_id       = data.aws_subnet.ad_subnet.id # Reference your specific subnet
  security_groups = [aws_security_group.efs_sg.id]
}

