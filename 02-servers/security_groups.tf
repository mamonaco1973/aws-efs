# WARNING: This configuration allows unrestricted access from the internet (0.0.0.0/0)
# It is highly insecure and should be restricted to trusted IPs.
# Consider limiting access to known CIDR ranges instead.

# Security Group for RDP (Port 3389) - Used for Remote Desktop Protocol access to Windows instances
resource "aws_security_group" "ad_rdp_sg" {
  name        = "ad-rdp-security-group"              # Security Group name
  description = "Allow RDP access from the internet" # Description of the security group
  vpc_id      = data.aws_vpc.ad_vpc.id               # Associates the security group with the specified VPC

  # INGRESS: Defines inbound rules allowing access to port 3389 (RDP)
  ingress {
    description = "Allow RDP from anywhere" # This rule permits RDP access from all IPs
    from_port   = 3389                      # Start of port range (RDP default port)
    to_port     = 3389                      # End of port range (same as start for a single port)
    protocol    = "tcp"                     # Protocol type (TCP for RDP)
    cidr_blocks = ["0.0.0.0/0"]             # WARNING: Allows traffic from ANY IP address (highly insecure!)
  }

  # INGRESS: Defines inbound rules allowing ICMP (ping)
  ingress {
    description = "Allow ICMP (ping) from anywhere"
    from_port   = -1 # ICMP doesn't use ports, so use -1
    to_port     = -1
    protocol    = "icmp"        # Protocol type for ICMP
    cidr_blocks = ["0.0.0.0/0"] # WARNING: open to all IPs (fine for testing, restrict later)
  }


  # EGRESS: Allows all outbound traffic (default open rule)
  egress {
    from_port   = 0             # Start of port range (0 means all ports)
    to_port     = 0             # End of port range (0 means all ports)
    protocol    = "-1"          # Protocol (-1 means all protocols)
    cidr_blocks = ["0.0.0.0/0"] # Allows outbound traffic to ANY destination
  }
}

# Security Group for SSH (Port 22) - Used for Secure Shell access to Linux instances
resource "aws_security_group" "ad_ssh_sg" {
  name        = "ad-ssh-security-group"              # Security Group name
  description = "Allow SSH access from the internet" # Description of the security group
  vpc_id      = data.aws_vpc.ad_vpc.id               # Associates the security group with the specified VPC

  # INGRESS: Defines inbound rules allowing access to port 22 (SSH)
  ingress {
    description = "Allow SSH from anywhere" # This rule permits SSH access from all IPs
    from_port   = 22                        # Start of port range (SSH default port)
    to_port     = 22                        # End of port range (same as start for a single port)
    protocol    = "tcp"                     # Protocol type (TCP for SSH)
    cidr_blocks = ["0.0.0.0/0"]             # WARNING: Allows traffic from ANY IP address (highly insecure!)
  }

  # INGRESS: Defines inbound rules allowing access to port 445 (SMB)
  ingress {
    description = "Allow SMB from anywhere" # This rule permits SMB access from all IPs
    from_port   = 445                       # Start of port range (SMB default port)
    to_port     = 445                       # End of port range (same as start for a single port)
    protocol    = "tcp"                     # Protocol type (TCP for SMB)
    cidr_blocks = ["0.0.0.0/0"]             # WARNING: Allows traffic from ANY IP address (highly insecure!)
  }

  # INGRESS: Defines inbound rules allowing ICMP (ping)
  ingress {
    description = "Allow ICMP (ping) from anywhere"
    from_port   = -1 # ICMP doesn't use ports, so use -1
    to_port     = -1
    protocol    = "icmp"        # Protocol type for ICMP
    cidr_blocks = ["0.0.0.0/0"] # WARNING: open to all IPs (fine for testing, restrict later)
  }


  # EGRESS: Allows all outbound traffic (default open rule)
  egress {
    from_port   = 0             # Start of port range (0 means all ports)
    to_port     = 0             # End of port range (0 means all ports)
    protocol    = "-1"          # Protocol (-1 means all protocols)
    cidr_blocks = ["0.0.0.0/0"] # Allows outbound traffic to ANY destination
  }
}
