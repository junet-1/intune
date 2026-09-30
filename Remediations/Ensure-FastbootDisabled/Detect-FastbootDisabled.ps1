<#
.SYNOPSIS
    Intune Remediation - Detection: Checks that Windows Fast Startup (hybrid boot)
    is disabled.

.DESCRIPTION
    Reports NON-COMPLIANT (exit 1) if HiberbootEnabled is not 0. Fast Startup
    keeps a hibernation-like state across shutdowns and is a frequent cause of
    devices not applying updates, drivers or policies until a real restart. The
    remediation turns it off.

.NAME
    REM-D-WIN-FastbootDisabled

.NOTES
    Adapted from the community EndpointAnalyticsRemediationScripts (MIT).
    Context: run as SYSTEM (64-bit).
    Exit 0 = compliant, Exit 1 = non-compliant.
#>

$LogDir = 'C:\ProgramData\IntuneScripts\Logs'
$null = New-Item -ItemType Directory -Path $LogDir -Force
$Log = Join-Path $LogDir 'Detect-FastbootDisabled.log'
function Write-Log { param($m) Add-Content -Path $Log -Value ('{0} {1}' -f (Get-Date -Format u), $m); Write-Output $m }

$Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power'

try {
    $val = (Get-ItemProperty -Path $Path -Name 'HiberbootEnabled' -ErrorAction SilentlyContinue).HiberbootEnabled
    if ($val -eq 0) {
        Write-Log 'COMPLIANT: Fast Startup disabled.'
        exit 0
    }
    Write-Log "NON-COMPLIANT: Fast Startup enabled (HiberbootEnabled=$val)."
    exit 1
}
catch {
    Write-Log "ERROR during detection: $($_.Exception.Message)"
    exit 1
}

