<powershell>
# ================================================================================================
# Windows AD Administration Instance Bootstrap Script
# ================================================================================================
# Description:
#   This script configures a Windows EC2 instance as an Active Directory (AD) 
#   administration workstation/server. It installs required AD management tools,
#   sets up the AWS CLI, joins the instance to the AD domain, grants RDP access 
#   to a designated AD group, maps an EFS drive, and finally reboots to apply policies.
#
# Execution Context:
#   - Runs at first boot via EC2 User Data
#   - Requires IAM instance profile permissions to call AWS Secrets Manager
#   - Assumes Samba/EFS is already configured and accessible from the instance
#
# Key Features:
#   - Installs RSAT + GPMC for AD management
#   - Retrieves AD admin credentials securely from Secrets Manager
#   - Automates domain join and group membership assignment
#   - Creates a persistent mapped drive to EFS
#   - Forces a reboot to finalize configuration
# ================================================================================================

# --------------------------------------------------------------------------------
# Install Active Directory Management Components
# --------------------------------------------------------------------------------

# Suppress verbose progress output for faster/simpler execution
$ProgressPreference = 'SilentlyContinue'

# Install Windows features commonly used for AD management:
# - GPMC                : Group Policy Management Console
# - RSAT-AD-PowerShell  : Active Directory PowerShell cmdlets
# - RSAT-AD-AdminCenter : Active Directory Administrative Center
# - RSAT-ADDS-Tools     : AD DS and LDS tools (dsa.msc, etc.)
# - RSAT-DNS-Server     : DNS Manager console
Install-WindowsFeature -Name GPMC,RSAT-AD-PowerShell,RSAT-AD-AdminCenter,RSAT-ADDS-Tools,RSAT-DNS-Server

# --------------------------------------------------------------------------------
# Install AWS CLI v2
# --------------------------------------------------------------------------------

Write-Host "Installing AWS CLI..."

# Download AWS CLI installer MSI into Administrator’s profile
Invoke-WebRequest https://awscli.amazonaws.com/AWSCLIV2.msi -OutFile C:\Users\Administrator\AWSCLIV2.msi

# Install AWS CLI silently (no GUI prompts)
Start-Process "msiexec" -ArgumentList "/i C:\Users\Administrator\AWSCLIV2.msi /qn" -Wait -NoNewWindow

# Update PATH in current session so aws.exe is immediately usable
$env:Path += ";C:\Program Files\Amazon\AWSCLIV2"

# --------------------------------------------------------------------------------
# Join EC2 Instance to Active Directory Domain
# --------------------------------------------------------------------------------

# Retrieve domain admin credentials securely from AWS Secrets Manager.
# - ${admin_secret} is replaced by Terraform with the actual secret ID.
$secretValue = aws secretsmanager get-secret-value --secret-id ${admin_secret} --query SecretString --output text
$secretObject = $secretValue | ConvertFrom-Json

# Convert plaintext password to a SecureString and build a PSCredential object
$password = $secretObject.password | ConvertTo-SecureString -AsPlainText -Force
$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $secretObject.username, $password

# Join the instance to the specified AD domain
Add-Computer -DomainName "${domain_fqdn}" -Credential $cred -Force 

# --------------------------------------------------------------------------------
# Grant RDP Access to AD Group
# --------------------------------------------------------------------------------

Write-Output "Configuring RDP access for AD group 'mcloud-users'..."

# Define AD group that should be added to the local Remote Desktop Users group
$domainGroup = "MCLOUD\mcloud-users"

# Retry logic (up to 10 attempts) to handle timing issues with domain join
$maxRetries = 10
$retryDelay = 30

for ($i=1; $i -le $maxRetries; $i++) {
    try {
        Add-LocalGroupMember -Group "Remote Desktop Users" -Member $domainGroup -ErrorAction Stop
        Write-Output "SUCCESS: Added $domainGroup to Remote Desktop Users"
        break
    } catch {
        Write-Output "WARN: Attempt $i failed - waiting $retryDelay seconds..."
        Start-Sleep -Seconds $retryDelay
    }
}

# --------------------------------------------------------------------------------
# Map EFS as Persistent Drive (Z:)
# --------------------------------------------------------------------------------

# Create a startup batch script to map Z: to the EFS share via Samba
$startup = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp"
$batchFile = Join-Path $startup "map_drives.bat"

# Command mounts \\${samba_server}\efs persistently at logon
$command = "net use Z: \\${samba_server}\efs /persistent:yes"
Set-Content -Path $batchFile -Value $command -Encoding ASCII

# --------------------------------------------------------------------------------
# Final Reboot to Apply Changes
# --------------------------------------------------------------------------------

# Perform a reboot to complete domain join and apply GPOs
shutdown /r /t 5 /c "Initial EC2 reboot to join domain" /f /d p:4:1

</powershell>
