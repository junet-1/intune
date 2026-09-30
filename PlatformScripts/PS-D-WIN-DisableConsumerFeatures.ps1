<#
.SYNOPSIS
    Intune Platform Script: Turns off Windows consumer / advertising content
    machine-wide via policy registry keys.

.DESCRIPTION
    Disables consumer features (auto-installed promoted apps), Windows Spotlight
    consumer content, soft-landing tips and the news/interests widget. All values
    are written under HKLM policy keys, so they apply to every user. Idempotent.
    Runs as SYSTEM.

.NAME
    PS-D-WIN-DisableConsumerFeatures

.NOTES
    Assign as Platform script. Run as SYSTEM (logged-on credentials: No). 64-bit: Yes.
    Exit 0 = success, non-zero = failure.
#>

$ErrorActionPreference = 'Stop'

$LogDir = 'C:\ProgramData\IntuneScripts\Logs'
$null = New-Item -ItemType Directory -Path $LogDir -Force
$Log = Join-Path $LogDir 'PS-D-WIN-DisableConsumerFeatures.log'
function Write-Log { param($m) Add-Content -Path $Log -Value ('{0} {1}' -f (Get-Date -Format u), $m); Write-Output $m }

#region ---- Policy values ------------------------------------------------------
$Policies = @(
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Name = 'DisableWindowsConsumerFeatures';    Value = 1 }
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Name = 'DisableConsumerAccountStateContent'; Value = 1 }
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Name = 'DisableSoftLanding';                 Value = 1 }
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Name = 'DisableWindowsSpotlightFeatures';    Value = 1 }
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh';                  Name = 'AllowNewsAndInterests';              Value = 0 }  # widgets
)
#endregion ----------------------------------------------------------------------

try {
    foreach ($p in $Policies) {
        if (-not (Test-Path $p.Path)) { New-Item -Path $p.Path -Force | Out-Null }
        New-ItemProperty -Path $p.Path -Name $p.Name -Value $p.Value -PropertyType DWord -Force | Out-Null
        Write-Log "Set $($p.Name) = $($p.Value)"
    }

    Write-Log 'Done. Consumer features disabled.'
    exit 0
}
catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    exit 1
}

