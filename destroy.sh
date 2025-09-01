#!/bin/bash
# --------------------------------------------------------------------------------------------------
# This script performs a two-phase destruction process:
#   1. Deletes application/server EC2 instances using Terraform.
#   2. Deletes the Active Directory (AD) instance and associated AWS Secrets Manager
#      and SSM Parameter Store entries, followed by AD Terraform teardown.
#
# IMPORTANT:
#   - This script forcefully deletes sensitive secrets with no recovery window.
#   - The AWS CLI must be installed and configured with credentials that allow
#     deletion of EC2, Secrets Manager secrets, and SSM parameters.
#   - Terraform must be installed and initialized in each module directory.
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Configuration
# --------------------------------------------------------------------------------------------------
export AWS_DEFAULT_REGION="us-east-1"   # Region where AWS resources are deployed

# --------------------------------------------------------------------------------------------------
# Phase 1: Destroy server EC2 instances
# --------------------------------------------------------------------------------------------------
echo "NOTE: Destroying EC2 server instances..."
cd 02-servers || { echo "ERROR: Directory 02-servers not found"; exit 1; }

terraform init   # Re-initialize Terraform to ensure backend and providers are available
terraform destroy -auto-approve   # Destroy resources without interactive approval

cd .. || exit

# --------------------------------------------------------------------------------------------------
# Phase 2: Destroy AD instance and supporting resources
# --------------------------------------------------------------------------------------------------
echo "NOTE: Deleting AD-related AWS secrets and parameters..."

# Force delete secrets (no recovery period)
aws secretsmanager delete-secret --secret-id "akumar_ad_credentials" --force-delete-without-recovery
aws secretsmanager delete-secret --secret-id "jsmith_ad_credentials" --force-delete-without-recovery
aws secretsmanager delete-secret --secret-id "edavis_ad_credentials" --force-delete-without-recovery
aws secretsmanager delete-secret --secret-id "rpatel_ad_credentials" --force-delete-without-recovery
aws secretsmanager delete-secret --secret-id "admin_ad_credentials" --force-delete-without-recovery

# Destroy AD instance via Terraform
echo "NOTE: Destroying AD instance..."
cd 01-directory || { echo "ERROR: Directory 01-directory not found"; exit 1; }

terraform init
terraform destroy -auto-approve

cd .. || exit

# --------------------------------------------------------------------------------------------------
# Completion
# --------------------------------------------------------------------------------------------------
echo "NOTE: Infrastructure destruction complete."
