<#
.SYNOPSIS
    Intune Platform Script: Enables "Set time zone automatically".

.DESCRIPTION
    Turns on the location capability and sets the tzautoupdate service to
    automatic so Windows keeps the time zone in sync with the device location.
    Idempotent - safe to run at every check-in. Runs as SYSTEM.

.NAME
    PS-D-WIN-TimeZoneAuto

.NOTES
    Assign as: Devices > Scripts and remediations > Platform scripts.
    Run this script using the logged-on credentials: No. 64-bit: Yes.
    Exit 0 = success, non-zero = failure (Intune retries).
#>

$ErrorActionPreference = 'Stop'

$LogDir = 'C:\ProgramData\IntuneScripts\Logs'
$null = New-Item -ItemType Directory -Path $LogDir -Force
$Log = Join-Path $LogDir 'PS-D-WIN-TimeZoneAuto.log'
function Write-Log { param($m) Add-Content -Path $Log -Value ('{0} {1}' -f (Get-Date -Format u), $m); Write-Output $m }

try {
    # Location must be allowed for automatic time zone to work.
    $loc = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location'
    if (-not (Test-Path $loc)) { New-Item -Path $loc -Force | Out-Null }
    New-ItemProperty -Path $loc -Name 'Value' -Value 'Allow' -PropertyType String -Force | Out-Null
    Write-Log 'Location consent set to Allow.'

    # tzautoupdate Start = 3 (Automatic / enabled).
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\tzautoupdate' -Name 'Start' -Value 3
    Set-Service -Name tzautoupdate -StartupType Automatic -ErrorAction SilentlyContinue
    Start-Service -Name tzautoupdate -ErrorAction SilentlyContinue
    Write-Log 'tzautoupdate enabled (automatic time zone ON).'

    exit 0
}
catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    exit 1
}

