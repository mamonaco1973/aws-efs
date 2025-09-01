# Define an IAM Role for EC2 instances to access AWS Secrets Manager
resource "aws_iam_role" "ec2_secrets_role" {
  name = "EC2SecretsAccessRole-${var.netbios}"

  # Define the trust policy allowing EC2 instances to assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com" # Only EC2 instances can assume this role
      }
      Action = "sts:AssumeRole" # Allows EC2 instances to request temporary credentials
    }]
  })
}

# Define an IAM Policy granting EC2 instances permission to read secrets from Secrets Manager
resource "aws_iam_policy" "secrets_policy" {
  name        = "SecretsManagerReadAccess"
  description = "Allows EC2 instance to read secrets from AWS Secrets Manager and manage IAM instance profiles"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Grant EC2 permission to retrieve secret values and list secrets
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue", # Fetch secret values
          "secretsmanager:DescribeSecret"  # Get metadata about secrets
        ]
        Resource = [
          data.aws_secretsmanager_secret.admin_secret.arn
        ]
      }
    ]
  })
}

# Attach the AmazonSSMManagedInstanceCore policy to the secrets role
# This allows EC2 instances using this role to interact with AWS Systems Manager (SSM)
resource "aws_iam_role_policy_attachment" "attach_ssm_policy" {
  role       = aws_iam_role.ec2_secrets_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Attach the Secrets Manager access policy to the EC2 Secrets role
resource "aws_iam_role_policy_attachment" "attach_secrets_policy" {
  role       = aws_iam_role.ec2_secrets_role.name
  policy_arn = aws_iam_policy.secrets_policy.arn # Custom policy granting Secrets Manager access
}

# Create an IAM Instance Profile for EC2 instances using the Secrets role
resource "aws_iam_instance_profile" "ec2_secrets_profile" {
  name = "EC2SecretsInstanceProfile-${var.netbios}"
  role = aws_iam_role.ec2_secrets_role.name # Associate the EC2SecretsAccessRole with this profile
}

