# ==================================================================================================
# Security Group: mini-ad-sg
# Purpose: Allow all required ports for a Samba-based Active Directory Domain Controller.
# NOTE: Currently open to all IPv4 (0.0.0.0/0) for simplicity — secure this in production.
# ==================================================================================================
resource "aws_security_group" "ad_sg" {
  name        = "mini-ad-sg"
  description = "Security group for mini Active Directory services (open to all IPv4)"
  vpc_id      = var.vpc_id

  # -----------------------------------
  # DNS (TCP/UDP 53) – name resolution for clients and AD replication
  # -----------------------------------
  ingress {
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # -----------------------------------
  # Kerberos Authentication (TCP/UDP 88)
  # -----------------------------------
  ingress {
    from_port   = 88
    to_port     = 88
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 88
    to_port     = 88
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # -----------------------------------
  # LDAP (TCP/UDP 389) – directory queries & updates
  # -----------------------------------
  ingress {
    from_port   = 389
    to_port     = 389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 389
    to_port     = 389
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # -----------------------------------
  # SMB/CIFS file sharing (TCP 445) – required for AD SYSVOL & NETLOGON shares
  # -----------------------------------
  ingress {
    from_port   = 445
    to_port     = 445
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # -----------------------------------
  # Kerberos Change/Set Password (TCP/UDP 464)
  # -----------------------------------
  ingress {
    from_port   = 464
    to_port     = 464
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 464
    to_port     = 464
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # -----------------------------------
  # RPC Endpoint Mapper (TCP 135) – locates RPC services
  # -----------------------------------
  ingress {
    from_port   = 135
    to_port     = 135
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # -----------------------------------
  # HTTPS (TCP 443) – required for AWS SSM connectivity
  # -----------------------------------
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # -----------------------------------
  # LDAP over SSL (TCP 636) – secure directory queries
  # -----------------------------------
  ingress {
    from_port   = 636
    to_port     = 636
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # -----------------------------------
  # Global Catalog (TCP 3268/3269) – forest-wide directory searches
  # -----------------------------------
  ingress {
    from_port   = 3268
    to_port     = 3268
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 3269
    to_port     = 3269
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # -----------------------------------
  # Ephemeral RPC Ports (TCP 49152–65535) – dynamic RPC communications
  # -----------------------------------
  ingress {
    from_port   = 49152
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # -----------------------------------
  # NTP (UDP 123) – time synchronization
  # -----------------------------------
  ingress {
    from_port   = 123
    to_port     = 123
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # -----------------------------------
  # Allow all outbound traffic (full egress)
  # -----------------------------------
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "mini-ad-sg" }
}
