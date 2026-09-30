<#
.SYNOPSIS
    Intune Remediation - Detection: Checks that SMB signing is required for both
    the SMB client and server.

.DESCRIPTION
    Reports NON-COMPLIANT (exit 1) if RequireSecuritySignature is not set to 1
    for LanmanWorkstation (client) or LanmanServer (server). Required SMB signing
    protects against SMB relay / tampering. The remediation sets both to 1.

.NAME
    REM-D-WIN-SmbSigning

.NOTES
    Adapted from the community EndpointAnalyticsRemediationScripts (MIT); the
    original used invalid registry paths (HKLM without the provider colon).
    Context: run as SYSTEM (64-bit).
    Exit 0 = compliant, Exit 1 = non-compliant.
#>

$LogDir = 'C:\ProgramData\IntuneScripts\Logs'
$null = New-Item -ItemType Directory -Path $LogDir -Force
$Log = Join-Path $LogDir 'Detect-SMBSigning.log'
function Write-Log { param($m) Add-Content -Path $Log -Value ('{0} {1}' -f (Get-Date -Format u), $m); Write-Output $m }

$Targets = @(
    'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters'
    'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters'
)

try {
    $bad = @()
    foreach ($path in $Targets) {
        $val = (Get-ItemProperty -Path $path -Name 'RequireSecuritySignature' -ErrorAction SilentlyContinue).RequireSecuritySignature
        if ($val -ne 1) { $bad += (Split-Path $path -Parent | Split-Path -Leaf) }
    }

    if ($bad.Count -gt 0) {
        Write-Log "NON-COMPLIANT: SMB signing not required for: $($bad -join ', ')."
        exit 1
    }
    Write-Log 'COMPLIANT: SMB signing required for client and server.'
    exit 0
}
catch {
    Write-Log "ERROR during detection: $($_.Exception.Message)"
    exit 1
}

