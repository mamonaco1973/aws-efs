<powershell>
$ErrorActionPreference = 'Stop'
$ProgressPreference   = 'SilentlyContinue'

$Log = 'C:\ProgramData\userdata.log'
New-Item -Path $Log -ItemType File -Force | Out-Null

& {
    $VerbosePreference     = 'Continue'
    $InformationPreference = 'Continue'
    $WarningPreference     = 'Continue'

    Write-Output "Starting PowerShell user-data at $(Get-Date -Format o)"

    Install-WindowsFeature -Name GPMC,RSAT-AD-PowerShell,RSAT-AD-AdminCenter,RSAT-ADDS-Tools,RSAT-DNS-Server

    Write-Output "Downloading AWS CLI v2 installer"
    Invoke-WebRequest https://awscli.amazonaws.com/AWSCLIV2.msi -OutFile C:\Users\Administrator\AWSCLIV2.msi

    Write-Output "Installing AWS CLI v2"
    Start-Process msiexec -ArgumentList "/i C:\Users\Administrator\AWSCLIV2.msi /qn" -Wait -NoNewWindow
    $env:Path += ";C:\Program Files\Amazon\AWSCLIV2"

    Write-Output "Retrieving domain join credentials from Secrets Manager"
    $secretValue  = aws secretsmanager get-secret-value --secret-id ${admin_secret} --query SecretString --output text
    $secretObject = $secretValue | ConvertFrom-Json

    $password = $secretObject.password | ConvertTo-SecureString -AsPlainText -Force
    $cred     = New-Object System.Management.Automation.PSCredential ($secretObject.username, $password)

    Write-Output "Joining AD domain ${domain_fqdn}"
    Add-Computer -DomainName "${domain_fqdn}" -Credential $cred -Force

    Write-Output "Adding MCLOUD\mcloud-users to Remote Desktop Users"
    $domainGroup = "MCLOUD\mcloud-users"
    $maxRetries  = 10
    $retryDelay  = 30

    for ($i = 1; $i -le $maxRetries; $i++) {
        try {
            Write-Output "Attempt $i: Add-LocalGroupMember"
            Add-LocalGroupMember -Group "Remote Desktop Users" -Member $domainGroup -ErrorAction Stop
            Write-Output "SUCCESS: Added $domainGroup to Remote Desktop Users"
            break
        } catch {
            Write-Output "WARN: Attempt $i failed - waiting $retryDelay seconds..."
            Start-Sleep -Seconds $retryDelay
        }
    }

    Write-Output "Creating startup drive mapping (Z: -> \\${samba_server}\efs)"
    $startup   = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp"
    $batchFile = Join-Path $startup "map_drives.bat"
    $command   = "net use Z: \\${samba_server}\efs /persistent:yes"
    Set-Content -Path $batchFile -Value $command -Encoding ASCII

    Write-Output "Rebooting to finalize domain join"
    shutdown /r /t 5 /c "Initial EC2 reboot to join domain" /f /d p:4:1

} *> &1 | Tee-Object -FilePath $Log -Append
</powershell>
