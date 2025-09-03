# ================================================================================================
# EC2 Instance: Windows AD Administration Server
# ================================================================================================
# Provisions a Windows Server EC2 instance that serves as an administrative workstation
# for managing the Active Directory (AD) environment.
#
# Key Points:
#   - This is NOT a Domain Controller. It is a management box used for RDP logins,
#     running administrative tools (e.g., RSAT, ADUC, PowerShell modules), and
#     interacting with the AD domain.
#   - Designed to connect to and manage AD services running on separate infrastructure.
# ================================================================================================
resource "aws_instance" "windows_ad_instance" {

  # ----------------------------------------------------------------------------------------------
  # Amazon Machine Image (AMI)
  # ----------------------------------------------------------------------------------------------
  # References a Windows Server AMI ID, dynamically resolved from a data source.
  # Ensures the latest supported Windows AMI is used for administration purposes.
  ami = data.aws_ami.windows_ami.id

  # ----------------------------------------------------------------------------------------------
  # Instance Type
  # ----------------------------------------------------------------------------------------------
  # Specifies the compute and memory profile of the instance.
  # "t3.medium" provides 2 vCPUs and 4 GiB of RAM — sufficient for running AD admin tools,
  # remote management consoles, and supporting RDP sessions.
  instance_type = "t3.medium"

  # ----------------------------------------------------------------------------------------------
  # Networking
  # ----------------------------------------------------------------------------------------------
  # - Launches the instance into the specified VPC subnet.
  # - Networking rules are enforced through security groups.
  subnet_id = data.aws_subnet.vm_subnet_1.id

  vpc_security_group_ids = [
    aws_security_group.ad_rdp_sg.id  # Allows inbound RDP (TCP/3389) for Windows administration
    # Extend with SSM security group if AWS Systems Manager is used for management
  ]

  # Assign a public IP at launch.
  # WARNING: With permissive SG rules, this exposes the instance to the internet.
  # Recommended to restrict RDP to trusted IPs (e.g., VPN or admin workstation ranges).
  associate_public_ip_address = true

  # ----------------------------------------------------------------------------------------------
  # IAM Role / Instance Profile
  # ----------------------------------------------------------------------------------------------
  # Attaches an IAM instance profile granting the instance permission to access AWS resources
  # securely (e.g., retrieving secrets from Secrets Manager, accessing SSM).
  iam_instance_profile = aws_iam_instance_profile.ec2_secrets_profile.name

  # ----------------------------------------------------------------------------------------------
  # User Data (Bootstrapping)
  # ----------------------------------------------------------------------------------------------
  # Executes a PowerShell script at first boot to configure the instance with:
  # - admin_secret   : AWS Secrets Manager entry for admin credentials
  # - domain_fqdn    : Fully Qualified Domain Name of the AD environment
  # - samba_server   : Private DNS name of the Samba/EFS client instance (for integration)
  user_data = templatefile("./scripts/userdata.ps1", {
    admin_secret = "admin_ad_credentials"
    domain_fqdn  = var.dns_zone
    samba_server = aws_instance.efs_client_instance.private_dns
  })

  # ----------------------------------------------------------------------------------------------
  # Tags
  # ----------------------------------------------------------------------------------------------
  # Standard AWS metadata tags for identification, cost allocation, and automation workflows.
  tags = {
    Name = "windows-ad-admin" # Clarified role: AD Admin workstation/server
  }

  # ----------------------------------------------------------------------------------------------
  # Dependencies
  # ----------------------------------------------------------------------------------------------
  # Ensure that the Samba/EFS client instance is created first,
  # since this admin box may connect to it for management tasks.
  depends_on = [aws_instance.efs_client_instance]
}
