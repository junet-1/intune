<#
.SYNOPSIS
    Intune Platform Script: Applies a sensible power configuration - the device
    never sleeps on AC power, the display turns off after a configurable idle.

.DESCRIPTION
    Uses powercfg to set standby and hibernate timeouts to 0 (never) on AC and to
    turn the monitor off after the configured minutes. Battery (DC) timeouts are
    set to modest values. Idempotent. Runs as SYSTEM.

.PARAMETER MonitorTimeoutAcMinutes
    Minutes of inactivity before the display turns off on AC power. Default 15.

.PARAMETER MonitorTimeoutDcMinutes
    Same on battery. Default 10.

.NAME
    PS-D-WIN-PowerConfig

.NOTES
    Assign as Platform script. Run as SYSTEM (logged-on credentials: No). 64-bit: Yes.
    Exit 0 = success, non-zero = failure.
#>

param(
    [int]$MonitorTimeoutAcMinutes = 15,
    [int]$MonitorTimeoutDcMinutes = 10
)

$ErrorActionPreference = 'Stop'

$LogDir = 'C:\ProgramData\IntuneScripts\Logs'
$null = New-Item -ItemType Directory -Path $LogDir -Force
$Log = Join-Path $LogDir 'PS-D-WIN-PowerConfig.log'
function Write-Log { param($m) Add-Content -Path $Log -Value ('{0} {1}' -f (Get-Date -Format u), $m); Write-Output $m }

try {
    # Never sleep / hibernate while on AC.
    & powercfg.exe /change standby-timeout-ac 0
    & powercfg.exe /change hibernate-timeout-ac 0
    # Modest battery timeouts.
    & powercfg.exe /change standby-timeout-dc 30
    & powercfg.exe /change hibernate-timeout-dc 60
    # Display off after idle.
    & powercfg.exe /change monitor-timeout-ac $MonitorTimeoutAcMinutes
    & powercfg.exe /change monitor-timeout-dc $MonitorTimeoutDcMinutes

    Write-Log "Power config applied (no sleep on AC, monitor AC=$MonitorTimeoutAcMinutes min, DC=$MonitorTimeoutDcMinutes min)."
    exit 0
}
catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    exit 1
}

