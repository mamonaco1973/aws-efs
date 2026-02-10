<powershell>
$ErrorActionPreference = 'Stop'
$ProgressPreference   = 'SilentlyContinue'

# Centralized user-data log
$Log = 'C:\ProgramData\userdata.log'
New-Item -Path $Log -ItemType File -Force | Out-Null

Write-Output "Starting PowerShell user-data at $(Get-Date -Format o)"
Start-Transcript -Path $Log -Append

try {
    & {
        $VerbosePreference     = 'Continue'
        $InformationPreference = 'Continue'
        $WarningPreference     = 'Continue'

        Write-Output "Installing Active Directory management features (RSAT, GPMC, DNS)"
        Install-WindowsFeature -Name `
            GPMC,RSAT-AD-PowerShell,RSAT-AD-AdminCenter,RSAT-ADDS-Tools,RSAT-DNS-Server
        Write-Output "AD management feature installation complete"

        Write-Output "Downloading AWS CLI v2 installer"
        Invoke-WebRequest https://awscli.amazonaws.com/AWSCLIV2.msi `
            -OutFile C:\Users\Administrator\AWSCLIV2.msi

        Write-Output "Installing AWS CLI v2"
        Start-Process msiexec `
            -ArgumentList "/i C:\Users\Administrator\AWSCLIV2.msi /qn" `
            -Wait -NoNewWindow
        $env:Path += ";C:\Program Files\Amazon\AWSCLIV2"
        Write-Output "AWS CLI installation complete"

        Write-Output "Retrieving domain join credentials from Secrets Manager"
        $secretValue = aws secretsmanager get-secret-value `
            --secret-id ${admin_secret} `
            --query SecretString `
            --output text
        $secretObject = $secretValue | ConvertFrom-Json
        Write-Output "Secret retrieved successfully"

        Write-Output "Preparing credential object for domain join"
        $password = $secretObject.password | ConvertTo-SecureString -AsPlainText -Force
        $cred     = New-Object `
            System.Management.Automation.PSCredential `
            ($secretObject.username, $password)

        Write-Output "Joining Active Directory domain ${domain_fqdn}"
        Add-Computer -DomainName "${domain_fqdn}" -Credential $cred -Force
        Write-Output "Domain join command issued successfully"

        Write-Output "Configuring RDP access for AD group 'mcloud-users'"
        $domainGroup = "MCLOUD\mcloud-users"
        $maxRetries  = 10
        $retryDelay  = 30

        for ($i = 1; $i -le $maxRetries; $i++) {
            try {
                Write-Output "Attempt $i : adding $domainGroup to Remote Desktop Users"
                Add-LocalGroupMember `
                    -Group "Remote Desktop Users" `
                    -Member $domainGroup `
                    -ErrorAction Stop
                Write-Output "SUCCESS: $domainGroup added to Remote Desktop Users"
                break
            } catch {
                Write-Output "WARNING: Attempt $i failed, retrying in $retryDelay seconds"
                Start-Sleep -Seconds $retryDelay
            }
        }

        Write-Output "Creating persistent drive mapping for EFS (Z:)"
        $startup   = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp"
        $batchFile = Join-Path $startup "map_drives.bat"
        $command   = "net use Z: \\${samba_server}\efs /persistent:yes"
        Set-Content -Path $batchFile -Value $command -Encoding ASCII
        Write-Output "Startup drive mapping script created"

        Write-Output "Rebooting instance to finalize domain join and apply group policy"
        shutdown /r /t 5 /c "Initial EC2 reboot to join domain" /f /d p:4:1

    } *>> $Log
}
finally {
    Write-Output "User-data execution complete at $(Get-Date -Format o)"
    Stop-Transcript | Out-Null
}
</powershell>
