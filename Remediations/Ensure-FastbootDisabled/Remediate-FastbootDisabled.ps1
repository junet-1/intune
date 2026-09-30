<#
.SYNOPSIS
    Intune Remediation - Remediation: Disables Windows Fast Startup (hybrid boot).

.DESCRIPTION
    Sets HiberbootEnabled = 0 so a shutdown is a real shutdown. Idempotent.
    Existing sessions are unaffected; the change applies from the next shutdown.

.NAME
    Disable Fast Startup

.NOTES
    Adapted from the community EndpointAnalyticsRemediationScripts (MIT).
    Context: run as SYSTEM (64-bit).
    Exit 0 = success, Exit 1 = error.
#>

$LogDir = 'C:\ProgramData\IntuneScripts\Logs'
$null = New-Item -ItemType Directory -Path $LogDir -Force
$Log = Join-Path $LogDir 'Remediate-FastbootDisabled.log'
function Write-Log { param($m) Add-Content -Path $Log -Value ('{0} {1}' -f (Get-Date -Format u), $m); Write-Output $m }

$Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power'

try {
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    New-ItemProperty -Path $Path -Name 'HiberbootEnabled' -Value 0 -PropertyType DWord -Force | Out-Null

    if ((Get-ItemProperty -Path $Path -Name 'HiberbootEnabled').HiberbootEnabled -eq 0) {
        Write-Log 'OK: Fast Startup disabled.'
        exit 0
    }
    Write-Log 'ERROR: HiberbootEnabled not 0 after remediation.'
    exit 1
}
catch {
    Write-Log "ERROR during remediation: $($_.Exception.Message)"
    exit 1
}

