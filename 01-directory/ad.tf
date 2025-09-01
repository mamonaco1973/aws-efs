# ==========================================================================================
# Mini Active Directory (mini-ad) Module Invocation
# ------------------------------------------------------------------------------------------
# Purpose:
#   - Calls the reusable "mini-ad" module to provision an Ubuntu-based AD Domain Controller
#   - Passes in networking, DNS, and authentication parameters
#   - Supplies user account definitions via a JSON blob generated from a template
# ==========================================================================================

module "mini_ad" {
  source            = "github.com/mamonaco1973/module-aws-mini-ad" # GitHub repo source
  netbios           = var.netbios                                  # NetBIOS domain name (e.g., MCLOUD)
  vpc_id            = aws_vpc.ad-vpc.id                            # VPC where the AD will reside
  realm             = var.realm                                    # Kerberos realm (usually UPPERCASE DNS domain)
  users_json        = local.users_json                             # JSON blob of users and passwords (built below)
  user_base_dn      = var.user_base_dn                             # Base DN for user accounts in LDAP
  ad_admin_password = random_password.admin_password.result        # Randomized AD administrator password
  dns_zone          = var.dns_zone                                 # DNS zone (e.g., mcloud.mikecloud.com)
  subnet_id         = aws_subnet.ad-subnet.id                      # Subnet for AD VM placement

  # Ensure NAT + route association exist before bootstrapping (for package repos, etc.)
  depends_on = [
    aws_nat_gateway.ad_nat,
    aws_route_table_association.rt_assoc_ad_private
  ]
}

# ==========================================================================================
# Local Variable: users_json
# ------------------------------------------------------------------------------------------
# - Renders a JSON file (`users.json.template`) into a single JSON blob
# - Injects unique random passwords for test/demo users
# - Template variables are replaced with real values at runtime
# - Passed into the VM bootstrap so users are created automatically
# ==========================================================================================

locals {
  users_json = templatefile("./scripts/users.json.template", {
    USER_BASE_DN    = var.user_base_dn                       # Base DN for placing new users in LDAP
    DNS_ZONE        = var.dns_zone                           # AD-integrated DNS zone
    REALM           = var.realm                              # Kerberos realm (FQDN in uppercase)
    NETBIOS         = var.netbios                            # NetBIOS domain name
    jsmith_password = random_password.jsmith_password.result # Random password for John Smith
    edavis_password = random_password.edavis_password.result # Random password for Emily Davis
    rpatel_password = random_password.rpatel_password.result # Random password for Raj Patel
    akumar_password = random_password.akumar_password.result # Random password for Amit Kumar
  })
}
