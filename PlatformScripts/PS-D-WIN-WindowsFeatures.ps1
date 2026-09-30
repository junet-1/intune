<#
.SYNOPSIS
    Intune Platform Script: Adds, disables and removes Windows features.

.DESCRIPTION
    Three separate lists, all applied with DISM against the running OS:
    capabilities to remove, optional features to disable, and features on demand
    to add. Adding a FOD downloads it from Windows Update, so a WSUS policy is
    temporarily disabled for the duration and restored afterwards - without that,
    the download fails on devices pointed at an internal update server.

    Individual failures are logged and do not abort the run. Idempotent: entries
    already in the desired state are skipped. Runs as SYSTEM.

.NAME
    PS-D-WIN-WindowsFeatures

.RUNAS
    system

.RUN32
    false

.ENFORCESIGNATURE
    false

.NOTES
    Assign as Platform script. Run as SYSTEM (logged-on credentials: No). 64-bit: Yes.
    Some changes want a restart; -NoRestart is used, so schedule one separately.
    Names come from Get-WindowsCapability -Online and Get-WindowsOptionalFeature -Online.
    Exit 0 = finished, 1 = could not enumerate.
#>

$ErrorActionPreference = 'Stop'

# Capability names without the tilde suffix and version
$RemoveCapabilities = @(
    'App.StepsRecorder'
    'Microsoft.Windows.PowerShell.ISE'
)

# Feature names as returned by Get-WindowsOptionalFeature -Online
$DisableOptionalFeatures = @(
    'MicrosoftWindowsPowershellV2Root'
    'WorkFolders-Client'
    'Recall'
    'MediaPlayback'
)

# Full capability names including the tilde suffix
$AddFeatures = @(
    'Microsoft.Windows.Sense.Client~~~~'
    'WMIC'
)

$LogDir = 'C:\ProgramData\IntuneScripts\Logs'
$null = New-Item -ItemType Directory -Path $LogDir -Force
$Log = Join-Path $LogDir 'PS-D-WIN-WindowsFeatures.log'
function Write-Log { param($m) Add-Content -Path $Log -Value ('{0} {1}' -f (Get-Date -Format u), $m); Write-Output $m }

Write-Log '=== PS-D-WIN-WindowsFeatures started ==='

# ---- Point Windows Update at the internet for the duration --------------------
$AuKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
$currentWU = (Get-ItemProperty -Path $AuKey -ErrorAction Ignore).UseWuServer
if ($currentWU -eq 1) {
    Write-Log 'WSUS is configured - disabling it temporarily so FODs can download'
    Set-ItemProperty -Path $AuKey -Name UseWuServer -Value 0
    Restart-Service wuauserv
}

try {
    # ---- Disable optional features --------------------------------------------
    try {
        $enabled = Get-WindowsOptionalFeature -Online | Where-Object State -eq 'Enabled'
        foreach ($f in $enabled) {
            if ($DisableOptionalFeatures -notcontains $f.FeatureName) { continue }
            try {
                Disable-WindowsOptionalFeature -Online -FeatureName $f.FeatureName -NoRestart | Out-Null
                Write-Log "  disabled optional feature: $($f.FeatureName)"
            } catch {
                Write-Log "  FAILED to disable $($f.FeatureName): $($_.Exception.Message)"
            }
        }
    } catch {
        Write-Log "Could not enumerate optional features: $($_.Exception.Message)"
    }

    # ---- Remove capabilities ---------------------------------------------------
    try {
        $installed = Get-WindowsCapability -Online | Where-Object State -eq 'Installed'
        foreach ($c in $installed) {
            if ($RemoveCapabilities -notcontains $c.Name.Split('~')[0]) { continue }
            try {
                Remove-WindowsCapability -Online -Name $c.Name | Out-Null
                Write-Log "  removed capability: $($c.Name)"
            } catch {
                Write-Log "  FAILED to remove $($c.Name): $($_.Exception.Message)"
            }
        }
    } catch {
        Write-Log "Could not enumerate capabilities: $($_.Exception.Message)"
    }

    # ---- Add features on demand ------------------------------------------------
    foreach ($name in $AddFeatures) {
        try {
            $result = Add-WindowsCapability -Online -Name $name
            if ($result.RestartNeeded) { Write-Log "  added capability (restart pending): $name" }
            else { Write-Log "  added capability: $name" }
        } catch {
            Write-Log "  FAILED to add ${name}: $($_.Exception.Message)"
        }
    }
}
finally {
    # ---- Restore the WSUS setting whatever happened above ---------------------
    if ($currentWU -eq 1) {
        Write-Log 'Restoring WSUS setting'
        Set-ItemProperty -Path $AuKey -Name UseWuServer -Value 1
        Restart-Service wuauserv
    }
}

Write-Log '=== Finished ==='
exit 0

