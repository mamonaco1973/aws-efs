#!/bin/bash
# ================================================================================================
# Active Directory + Dependent Server Infrastructure Teardown Script
# ================================================================================================
# Description:
#   This script automates a controlled, two-phase destruction of AWS-based infrastructure:
#     1. Tears down application/server EC2 instances provisioned by Terraform.
#     2. Deletes the Active Directory (AD) Domain Controller, along with sensitive
#        AWS Secrets Manager secrets and SSM parameters, then runs AD Terraform teardown.
#
# IMPORTANT:
#   - Secrets are deleted permanently with --force-delete-without-recovery (no restore window).
#   - Ensure the AWS CLI is installed and configured with credentials/permissions
#     to delete EC2 instances and Secrets Manager secrets
#   - Terraform must be installed and initialized within each module directory.
#   - Run this script only if you are certain you want to fully dismantle the environment.
#
# Exit Codes:
#   - 0 : Successful completion.
#   - 1 : Failure due to missing directories or Terraform/AWS CLI errors.
# ================================================================================================

# ------------------------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------------------------
export AWS_DEFAULT_REGION="us-east-1"   # AWS region for all deployed resources

# ------------------------------------------------------------------------------------------------
# Phase 1: Destroy Server EC2 Instances
# ------------------------------------------------------------------------------------------------
echo "NOTE: Destroying EC2 server instances..."

# Navigate to server module directory
cd 02-servers || { echo "ERROR: Directory 02-servers not found"; exit 1; }

# Reinitialize Terraform (ensures backend/plugins are ready before destroy)
terraform init

# Force-destroy server resources without requiring interactive approval
terraform destroy -auto-approve

# Return to root directory
cd .. || exit

# ------------------------------------------------------------------------------------------------
# Phase 2: Destroy AD Instance and Supporting Resources
# ------------------------------------------------------------------------------------------------
echo "NOTE: Deleting AD-related AWS secrets and parameters..."

# Permanently delete AD user/admin secrets from AWS Secrets Manager
# WARNING: --force-delete-without-recovery removes the secret immediately with no recovery window.
aws secretsmanager delete-secret --secret-id "akumar_ad_credentials" --force-delete-without-recovery
aws secretsmanager delete-secret --secret-id "jsmith_ad_credentials" --force-delete-without-recovery
aws secretsmanager delete-secret --secret-id "edavis_ad_credentials" --force-delete-without-recovery
aws secretsmanager delete-secret --secret-id "rpatel_ad_credentials" --force-delete-without-recovery
aws secretsmanager delete-secret --secret-id "admin_ad_credentials" --force-delete-without-recovery


# Destroy the AD instance via Terraform
echo "NOTE: Destroying AD instance..."

cd 01-directory || { echo "ERROR: Directory 01-directory not found"; exit 1; }

terraform init
terraform destroy -auto-approve

cd .. || exit

# ------------------------------------------------------------------------------------------------
# Completion
# ------------------------------------------------------------------------------------------------
echo "NOTE: Infrastructure destruction complete."
# ================================================================================================
# End of Script
# ================================================================================================
