<#
.SYNOPSIS
    Intune Remediation - Detection: Checks that the legacy SMBv1 protocol is
    disabled on the SMB server.

.DESCRIPTION
    Reports NON-COMPLIANT (exit 1) if SMBv1 is still enabled. SMBv1 is a legacy
    protocol and a known ransomware / worm vector (WannaCry, NotPetya); the
    remediation turns it off.

.NAME
    REM-D-WIN-SmbV1Disabled

.NOTES
    Adapted from the community EndpointAnalyticsRemediationScripts (MIT).
    Context: run as SYSTEM (64-bit).
    Exit 0 = compliant, Exit 1 = non-compliant.
#>

$LogDir = 'C:\ProgramData\IntuneScripts\Logs'
$null = New-Item -ItemType Directory -Path $LogDir -Force
$Log = Join-Path $LogDir 'Detect-SMBv1Disabled.log'
function Write-Log { param($m) Add-Content -Path $Log -Value ('{0} {1}' -f (Get-Date -Format u), $m); Write-Output $m }

try {
    $cfg = Get-SmbServerConfiguration -ErrorAction Stop
    if (-not $cfg.EnableSMB1Protocol) {
        Write-Log 'COMPLIANT: SMBv1 is disabled.'
        exit 0
    }
    Write-Log 'NON-COMPLIANT: SMBv1 is enabled.'
    exit 1
}
catch {
    Write-Log "ERROR during detection: $($_.Exception.Message)"
    exit 1
}

