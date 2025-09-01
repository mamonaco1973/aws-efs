# Generate a random password for the Active Directory (AD) Administrator
resource "random_password" "admin_password" {
  length           = 24    # Set password length to 24 characters
  special          = true  # Include special characters in the password
  override_special = "_-." # Limit special characters to this set
}

# Create an AWS Secrets Manager secret to store AD Admin credentials
resource "aws_secretsmanager_secret" "admin_secret" {
  name        = "admin_ad_credentials" # Name of the secret
  description = "AD Admin Credentials" # Description for reference

  lifecycle {
    prevent_destroy = false # Allow secret deletion if necessary
  }
}

# Store the admin credentials in AWS Secrets Manager with a versioned secret
resource "aws_secretsmanager_secret_version" "admin_secret_version" {
  secret_id = aws_secretsmanager_secret.admin_secret.id # Reference the secret
  secret_string = jsonencode({
    username = "${var.netbios}\\Admin"               # AD username
    password = random_password.admin_password.result # Generated password
  })
}

# --- User: John Smith ---

# Generate a random password for John Smith
resource "random_password" "jsmith_password" {
  length           = 24
  special          = true
  override_special = "!@#$%"
}

# Create a Secrets Manager entry for John Smith's credentials
resource "aws_secretsmanager_secret" "jsmith_secret" {
  name        = "jsmith_ad_credentials"
  description = "John Smith's AD Credentials"

  lifecycle {
    prevent_destroy = false
  }
}

# Store John Smith's AD credentials in AWS Secrets Manager
resource "aws_secretsmanager_secret_version" "jsmith_secret_version" {
  secret_id = aws_secretsmanager_secret.jsmith_secret.id
  secret_string = jsonencode({
    username = "${var.netbios}\\jsmith"
    password = random_password.jsmith_password.result
  })
}

# --- User: Emily Davis ---

# Generate a random password for Emily Davis
resource "random_password" "edavis_password" {
  length           = 24
  special          = true
  override_special = "!@#$%"
}

# Create a Secrets Manager entry for Emily Davis's credentials
resource "aws_secretsmanager_secret" "edavis_secret" {
  name        = "edavis_ad_credentials"
  description = "Emily Davis's AD Credentials"

  lifecycle {
    prevent_destroy = false
  }
}

# Store Emily Davis's AD credentials in AWS Secrets Manager
resource "aws_secretsmanager_secret_version" "edavis_secret_version" {
  secret_id = aws_secretsmanager_secret.edavis_secret.id
  secret_string = jsonencode({
    username = "${var.netbios}\\edavis"
    password = random_password.edavis_password.result
  })
}

# --- User: Raj Patel ---

# Generate a random password for Raj Patel
resource "random_password" "rpatel_password" {
  length           = 24
  special          = true
  override_special = "!@#$%"
}

# Create a Secrets Manager entry for Raj Patel's credentials
resource "aws_secretsmanager_secret" "rpatel_secret" {
  name        = "rpatel_ad_credentials"
  description = "Raj Patel's AD Credentials"

  lifecycle {
    prevent_destroy = false
  }
}

# Store Raj Patel's AD credentials in AWS Secrets Manager
resource "aws_secretsmanager_secret_version" "rpatel_secret_version" {
  secret_id = aws_secretsmanager_secret.rpatel_secret.id
  secret_string = jsonencode({
    username = "${var.netbios}\\rpatel"
    password = random_password.rpatel_password.result
  })
}

# --- User: Amit Kumar ---

# Generate a random password for Amit Kumar
resource "random_password" "akumar_password" {
  length           = 24
  special          = true
  override_special = "!@#$%"
}

# Create a Secrets Manager entry for Amit Kumar's credentials
resource "aws_secretsmanager_secret" "akumar_secret" {
  name        = "akumar_ad_credentials"
  description = "Amit Kumar's AD Credentials"

  lifecycle {
    prevent_destroy = false
  }
}

# Store Amit Kumar's AD credentials in AWS Secrets Manager
resource "aws_secretsmanager_secret_version" "akumar_secret_version" {
  secret_id = aws_secretsmanager_secret.akumar_secret.id
  secret_string = jsonencode({
    username = "${var.netbios}\\akumar"
    password = random_password.akumar_password.result
  })
}