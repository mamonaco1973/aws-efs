# EC2 INSTANCE CONFIGURATION
# This resource block defines an AWS EC2 instance named "windows_ad_instance".

resource "aws_instance" "windows_ad_instance" {

  # AMAZON MACHINE IMAGE (AMI)
  # Reference the Windows AMI ID fetched dynamically via the data source.
  # This ensures the latest or specific Windows Server version is used.

  ami = data.aws_ami.windows_ami.id

  # INSTANCE TYPE
  # Defines the compute power of the EC2 instance.
  # "t2.medium" is selected to provide more RAM and CPU power, 
  # since Windows requires more resources than Linux.

  instance_type = "t2.medium"

  # NETWORK CONFIGURATION - SUBNET
  # Specifies the AWS subnet where the instance will be deployed.
  # The subnet is dynamically retrieved from a data source (ad_subnet_2).
  # This determines whether the instance is public or private.

  subnet_id = data.aws_subnet.vm_subnet_1.id

  # SECURITY GROUPS
  # Applies two security groups:
  # 1. `ad_rdp_sg` - Allows Remote Desktop Protocol (RDP) access for Windows management.
  # 2. `ad_ssm_sg` - Allows AWS Systems Manager access for remote management.

  vpc_security_group_ids = [
    aws_security_group.ad_rdp_sg.id,
    aws_security_group.ad_ssm_sg.id
  ]

  # PUBLIC IP ASSIGNMENT
  # Ensures the instance gets a public IP upon launch for external access.
  # WARNING: This makes the instance reachable from the internet if security groups are misconfigured.

  associate_public_ip_address = true

  # SSH KEY PAIR (FOR ADMIN ACCESS)
  # Assigns an SSH key pair for secure access.
  # Even though this is a Windows instance, the key may be used for encrypted RDP authentication.

  # key_name = aws_key_pair.ec2_key_pair.key_name

  # IAM INSTANCE PROFILE
  # Assigns an IAM role with the necessary permissions for accessing AWS resources securely.
  # This is often used for granting access to S3, Secrets Manager, or other AWS services.

  iam_instance_profile = aws_iam_instance_profile.ec2_secrets_profile.name

  # USER DATA SCRIPT
  # Executes a PowerShell startup script (`userdata.ps1`) when the instance boots up.
  # This script is dynamically templated with values required for Windows Active Directory setup:
  # - `admin_secret`: The administrator credentials secret.
  # - `domain_fqdn`: The fully qualified domain name (FQDN) for the environment.
  # - `computers_ou`: The Organizational Unit where computers are registered in Active Directory.

  user_data = templatefile("./scripts/userdata.ps1", {
    admin_secret = "admin_ad_credentials" # The administrator credentials secret.
    domain_fqdn  = var.dns_zone           # The domain FQDN for Active Directory integration.
  })

  # INSTANCE TAGS
  # Metadata tag used to identify and organize resources in AWS.
  tags = {
    Name = "windows-ad-instance" # The EC2 instance name in AWS.
  }
}
