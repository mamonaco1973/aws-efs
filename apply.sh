#!/bin/bash
# --------------------------------------------------------------------------------------------------
# Description:
# This script provisions infrastructure in two main phases:
#   1. Deploys the Active Directory (AD) instance and ensures it is fully initialized.
#   2. Deploys additional EC2 servers that depend on the AD environment.
#
# Key Features:
#   - Validates the environment with a pre-check script before provisioning.
#   - Creates an SSM Parameter to track AD initialization status.
#   - Polls SSM Parameter Store until the AD Domain Controller signals readiness.
#   - Applies Terraform modules for both AD and server layers.
#   - Runs a validation script at the end to confirm the build.
#
# REQUIREMENTS:
#   - AWS CLI configured with appropriate credentials/permissions.
#   - Terraform installed and accessible in PATH.
#   - `check_env.sh` script present in the current directory.
#   - `validate.sh` script present in the current directory.
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# Configuration
# --------------------------------------------------------------------------------------------------
export AWS_DEFAULT_REGION="us-east-1"   # AWS region for all resources
DNS_ZONE="mcloud.mikecloud.com"         # Active Directory DNS zone / domain

# --------------------------------------------------------------------------------------------------
# Environment Pre-Check
# --------------------------------------------------------------------------------------------------
echo "NOTE: Running environment validation..."
./check_env.sh
if [ $? -ne 0 ]; then
  echo "ERROR: Environment check failed. Exiting."
  exit 1
fi

# --------------------------------------------------------------------------------------------------
# Phase 1: Build AD Instance
# --------------------------------------------------------------------------------------------------
echo "NOTE: Building Active Directory instance..."

cd 01-directory || { echo "ERROR: Directory 01-directory not found"; exit 1; }

terraform init
terraform apply -auto-approve

cd .. || exit

# --------------------------------------------------------------------------------------------------
# Phase 2: Build EC2 Server Instances
# --------------------------------------------------------------------------------------------------
echo "NOTE: Building EC2 server instances..."
cd 02-servers || { echo "ERROR: Directory 02-servers not found"; exit 1; }

terraform init
terraform apply -auto-approve

cd .. || exit

# --------------------------------------------------------------------------------------------------
# Build Validation
# --------------------------------------------------------------------------------------------------
echo "NOTE: Running build validation..."
./validate.sh

echo "NOTE: Infrastructure build complete."
