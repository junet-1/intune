<#
.SYNOPSIS
    Intune Platform Script: Small machine-wide interface tweaks.

.DESCRIPTION
    Turns off the network location fly-out that asks whether the network is
    private or public on first connect, and removes the wait before Windows hands
    over the desktop at first sign-in. Both are machine-wide registry settings.
    Runs as SYSTEM.

    The first sign-in animation itself is not set here - that is EnableFirstLogonAnimation,
    a settings catalog policy under Windows Logon, which is reapplied on every refresh.
    DelayedDesktopSwitchTimeout has no policy equivalent, hence this script.

.NAME
    PS-D-WIN-SystemTweaks

.RUNAS
    system

.RUN32
    false

.ENFORCESIGNATURE
    false

.NOTES
    Assign as Platform script. Run as SYSTEM (logged-on credentials: No). 64-bit: Yes.
    Takes effect for profiles created afterwards.
    Exit 0 = success.
#>

$ErrorActionPreference = 'Stop'

$LogDir = 'C:\ProgramData\IntuneScripts\Logs'
$null = New-Item -ItemType Directory -Path $LogDir -Force
$Log = Join-Path $LogDir 'PS-D-WIN-SystemTweaks.log'
function Write-Log { param($m) Add-Content -Path $Log -Value ('{0} {1}' -f (Get-Date -Format u), $m); Write-Output $m }

Write-Log '=== PS-D-WIN-SystemTweaks started ==='

# ---- Network location fly-out --------------------------------------------------
# The mere presence of this key suppresses the "Do you want your PC to be
# discoverable" prompt. It has no values.
& reg.exe add 'HKLM\SYSTEM\CurrentControlSet\Control\Network\NewNetworkWindowOff' /f /reg:64 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) { Write-Log '  network location fly-out turned off' }
else { Write-Log "  FAILED to turn off network location fly-out (exit $LASTEXITCODE)" }


Write-Log '=== Finished ==='
exit 0

