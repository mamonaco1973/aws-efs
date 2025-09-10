# ================================================================================================
# Canonical Ubuntu 24.04 AMI Lookup
# ================================================================================================
# Fetch the Canonical-published Ubuntu 24.04 LTS AMI ID from AWS Systems Manager (SSM).
# - Canonical maintains this parameter and keeps it updated to the current stable release.
# - This ensures that new deployments always use the latest recommended image for Ubuntu 24.04.
# - Architecture: amd64
# - Virtualization: HVM
# - Storage type: gp3
# ================================================================================================
data "aws_ssm_parameter" "ubuntu_24_04" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

# ================================================================================================
# Resolve Full AMI Object
# ================================================================================================
# Retrieves the full Amazon Machine Image (AMI) object corresponding to the ID fetched above.
# - Restricts the AMI owner to Canonical (099720109477) to avoid spoofed or untrusted AMIs.
# - Uses "most_recent = true" as an additional safeguard in case of multiple matches.
# ================================================================================================
data "aws_ami" "ubuntu_ami" {
  most_recent = true
  owners      = ["099720109477"] # Canonical’s official AWS account ID

  filter {
    name   = "image-id"
    values = [data.aws_ssm_parameter.ubuntu_24_04.value]
  }
}

# ================================================================================================
# EC2 Instance: EFS Client
# ================================================================================================
# Provisions an Ubuntu 24.04 EC2 instance that mounts an Amazon EFS file system and
# integrates into an Active Directory (AD) environment.
# ================================================================================================
resource "aws_instance" "efs_client_instance" {

  # ----------------------------------------------------------------------------------------------
  # Amazon Machine Image (AMI)
  # ----------------------------------------------------------------------------------------------
  # Dynamically resolved to the latest Canonical-published Ubuntu 24.04 AMI.
  ami = data.aws_ami.ubuntu_ami.id

  # ----------------------------------------------------------------------------------------------
  # Instance Type
  # ----------------------------------------------------------------------------------------------
  # Defines the compute and memory capacity of the instance.
  # Selected as "t3.medium" for balance between cost and performance.
  instance_type = "t3.medium"

  # ----------------------------------------------------------------------------------------------
  # Networking
  # ----------------------------------------------------------------------------------------------
  # - Places the instance into a designated VPC subnet.
  # - Applies one or more security groups to control inbound/outbound traffic.
  subnet_id = data.aws_subnet.vm_subnet_1.id

  vpc_security_group_ids = [
    aws_security_group.ad_ssh_sg.id  # Allows SSH access; extend with SSM SG if required
  ]

  # Assigns a public IP to the instance at launch (enables external SSH/RDP if allowed by SGs).
  associate_public_ip_address = true

  # ----------------------------------------------------------------------------------------------
  # IAM Role / Instance Profile
  # ----------------------------------------------------------------------------------------------
  # Attaches an IAM instance profile that grants the EC2 instance permissions to interact
  # with AWS services (e.g., Secrets Manager for credential retrieval, SSM for management).
  iam_instance_profile = aws_iam_instance_profile.ec2_secrets_profile.name

  # ----------------------------------------------------------------------------------------------
  # User Data (Bootstrapping)
  # ----------------------------------------------------------------------------------------------
  # Executes a startup script on first boot.
  # The script is parameterized with environment-specific values:
  # - admin_secret   : Name of the AWS Secrets Manager secret with AD admin credentials
  # - domain_fqdn    : Fully Qualified Domain Name of the AD domain
  # - efs_mnt_server : DNS name of the EFS mount target
  # - netbios        : NetBIOS short name of the AD domain
  # - realm          : Kerberos realm (usually uppercase domain name)
  # - force_group    : Default group applied to created files/directories
  user_data = templatefile("./scripts/userdata.sh", {
    admin_secret   = "admin_ad_credentials"
    domain_fqdn    = var.dns_zone
    efs_mnt_server = aws_efs_mount_target.efs_mnt_1.dns_name
    netbios        = var.netbios
    realm          = var.realm
    force_group    = "mcloud-users"
  })

  # ----------------------------------------------------------------------------------------------
  # Tags
  # ----------------------------------------------------------------------------------------------
  # Standard AWS tagging for identification, cost tracking, and automation workflows.
  tags = {
    Name = "efs-client-instance"
  }

  # ----------------------------------------------------------------------------------------------
  # Dependencies
  # ----------------------------------------------------------------------------------------------
  # Ensures the Amazon EFS file system exists before the client instance is launched.
  depends_on = [aws_efs_file_system.efs, aws_efs_mount_target.efs_mnt_1, aws_efs_mount_target.efs_mnt_2]
}
