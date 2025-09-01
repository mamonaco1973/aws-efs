# ==================================================================================================
# Variables for mini-ad module
# Purpose:
#   - Define all input parameters required for provisioning the Samba AD DC EC2
# ==================================================================================================

variable "dns_zone" {
  description = "DNS zone for the Samba AD domain (e.g., mcloud.mikecloud.com)."
  type        = string
}

variable "realm" {
  description = "Kerberos realm (typically uppercase form of DNS zone)."
  type        = string
}

variable "netbios" {
  description = "NetBIOS short name for the domain."
  type        = string
}

variable "user_base_dn" {
  description = "Base DN for user objects in LDAP (e.g., CN=Users,DC=mcloud,DC=mikecloud,DC=com)."
  type        = string
}

variable "instance_type" {
  description = "Size of the AD DC EC2 instance."
  type        = string
  default     = "t3.small"
}

variable "ad_admin_password" {
  description = "Password for the AD Administrator and Admin account used in Samba bootstrap."
  type        = string
  sensitive   = true
}

variable "subnet_id" {
  description = "ID of the subnet where the EC2 instance will be attached."
  type        = string
}

variable "vpc_id" {
  description = "ID of the Virtual Private Cloud (VPC) for DNS server updates."
  type        = string
}

variable "users_json" {
  description = "Pre-rendered JSON string containing user account definitions (from users.json.template)."
  type        = string
  default     = ""
}
