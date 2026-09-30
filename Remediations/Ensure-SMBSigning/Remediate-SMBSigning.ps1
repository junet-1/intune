<#
.SYNOPSIS
    Intune Remediation - Remediation: Requires SMB signing for both the SMB
    client and server.

.DESCRIPTION
    Sets RequireSecuritySignature = 1 under LanmanWorkstation (client) and
    LanmanServer (server). Idempotent. Creates the value if missing.

.NAME
    Enforce SMB Signing

.NOTES
    Adapted from the community EndpointAnalyticsRemediationScripts (MIT).
    Context: run as SYSTEM (64-bit).
    Exit 0 = success, Exit 1 = error.
#>

$LogDir = 'C:\ProgramData\IntuneScripts\Logs'
$null = New-Item -ItemType Directory -Path $LogDir -Force
$Log = Join-Path $LogDir 'Remediate-SMBSigning.log'
function Write-Log { param($m) Add-Content -Path $Log -Value ('{0} {1}' -f (Get-Date -Format u), $m); Write-Output $m }

$Targets = @(
    'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters'
    'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters'
)

try {
    foreach ($path in $Targets) {
        if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
        New-ItemProperty -Path $path -Name 'RequireSecuritySignature' -Value 1 -PropertyType DWord -Force | Out-Null
        Write-Log "Set RequireSecuritySignature=1 at $path"
    }

    $bad = @($Targets | Where-Object {
        (Get-ItemProperty -Path $_ -Name 'RequireSecuritySignature' -ErrorAction SilentlyContinue).RequireSecuritySignature -ne 1
    })
    if ($bad.Count -gt 0) {
        Write-Log "ERROR: still not required for: $($bad -join ', ')."
        exit 1
    }
    Write-Log 'OK: SMB signing required for client and server.'
    exit 0
}
catch {
    Write-Log "ERROR during remediation: $($_.Exception.Message)"
    exit 1
}

