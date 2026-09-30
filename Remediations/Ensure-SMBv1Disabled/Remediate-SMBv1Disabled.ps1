<#
.SYNOPSIS
    Intune Remediation - Remediation: Disables the legacy SMBv1 protocol on the
    SMB server.

.DESCRIPTION
    Turns SMBv1 off via Set-SmbServerConfiguration (with -Force, so it runs
    unattended as SYSTEM). Idempotent. A reboot is not required for the server
    configuration to take effect.

.NAME
    Disable SMBv1

.NOTES
    Adapted from the community EndpointAnalyticsRemediationScripts (MIT).
    Context: run as SYSTEM (64-bit).
    Exit 0 = success (or nothing to do), Exit 1 = error.
#>

$LogDir = 'C:\ProgramData\IntuneScripts\Logs'
$null = New-Item -ItemType Directory -Path $LogDir -Force
$Log = Join-Path $LogDir 'Remediate-SMBv1Disabled.log'
function Write-Log { param($m) Add-Content -Path $Log -Value ('{0} {1}' -f (Get-Date -Format u), $m); Write-Output $m }

try {
    if (-not (Get-SmbServerConfiguration -ErrorAction Stop).EnableSMB1Protocol) {
        Write-Log 'Nothing to do: SMBv1 already disabled.'
        exit 0
    }

    Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force -ErrorAction Stop

    if (-not (Get-SmbServerConfiguration).EnableSMB1Protocol) {
        Write-Log 'OK: SMBv1 disabled.'
        exit 0
    }
    Write-Log 'ERROR: SMBv1 still enabled after remediation.'
    exit 1
}
catch {
    Write-Log "ERROR during remediation: $($_.Exception.Message)"
    exit 1
}

