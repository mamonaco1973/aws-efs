<powershell>

# ------------------------------------------------------------
# Install Active Directory Components
# ------------------------------------------------------------

# Suppress progress bars to speed up execution
$ProgressPreference = 'SilentlyContinue'

# Install required Windows Features for Active Directory management
Install-WindowsFeature -Name GPMC,RSAT-AD-PowerShell,RSAT-AD-AdminCenter,RSAT-ADDS-Tools,RSAT-DNS-Server

# ------------------------------------------------------------
# Download and Install AWS CLI
# ------------------------------------------------------------

Write-Host "Installing AWS CLI..."

# Download the AWS CLI installer to the Administrator's folder
Invoke-WebRequest https://awscli.amazonaws.com/AWSCLIV2.msi -OutFile C:\Users\Administrator\AWSCLIV2.msi

# Run the installer silently without user interaction
Start-Process "msiexec" -ArgumentList "/i C:\Users\Administrator\AWSCLIV2.msi /qn" -Wait -NoNewWindow

# Manually append AWS CLI to system PATH for immediate availability
$env:Path += ";C:\Program Files\Amazon\AWSCLIV2"

# ------------------------------------------------------------
# Join EC2 Instance to Active Directory
# ------------------------------------------------------------

# Retrieve domain admin credentials from AWS Secrets Manager
$secretValue = aws secretsmanager get-secret-value --secret-id ${admin_secret} --query SecretString --output text
$secretObject = $secretValue | ConvertFrom-Json
$password = $secretObject.password | ConvertTo-SecureString -AsPlainText -Force
$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $secretObject.username, $password

# Join the EC2 instance to the Active Directory domain
Add-Computer -DomainName "${domain_fqdn}" -Credential $cred -Force 

# ------------------------------------------------------------
# Grant RDP Access to All Users in "mcloud-users" Group
# ------------------------------------------------------------

Write-Output "Add users to the Remote Desktop Users Group"
$domainGroup = "MCLOUD\mcloud-users"
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

# ------------------------------------------------------------
# MAP Z: to be EFS (via samba services)
# -----------------------------------------------------------

$startup = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp"
$batchFile = Join-Path $startup "map_drives.bat"
$command = "net use Z: \\${samba_server}\efs /persistent:yes"
Set-Content -Path $batchFile -Value $command -Encoding ASCII

# ------------------------------------------------------------
# Final Reboot to Apply Changes
# ------------------------------------------------------------

# Reboot the server to finalize the domain join and group policies
shutdown /r /t 5 /c "Initial EC2 reboot to join domain" /f /d p:4:1

</powershell>