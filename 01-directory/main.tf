# ================================================================================
# AWS Provider Configuration
# ================================================================================
# Purpose:
#   - Configures the AWS provider for all resources in this stack.
#
# Notes:
#   - Set the deployment region explicitly to avoid accidental cross-region builds.
# ================================================================================
provider "aws" {
  region = "us-east-1"
}
