<#
.SYNOPSIS
    Intune Remediation - Remediation: Sets UAC to automatically deny elevation
    requests from standard users.

.DESCRIPTION
    Setzt ConsentPromptBehaviorUser = 0. Idempotent. Die Aenderung greift ohne
    Neustart; bereits laufende Prozesse behalten ihr Token.

.NAME
    UAC Deny Elevation (Standard Users)

.NOTES
    Registry: HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System
    Context: run as SYSTEM (64-bit).
    Exit 0 = success, Exit 1 = error.
#>

$LogDir = 'C:\ProgramData\IntuneScripts\Logs'
$null = New-Item -ItemType Directory -Path $LogDir -Force
$Log = Join-Path $LogDir 'Remediate-UACDenyElevation.log'
function Write-Log { param($m) Add-Content -Path $Log -Value ('{0} {1}' -f (Get-Date -Format u), $m); Write-Output $m }

$Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'

try {
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    New-ItemProperty -Path $Path -Name 'ConsentPromptBehaviorUser' -Value 0 -PropertyType DWord -Force | Out-Null

    if ((Get-ItemProperty -Path $Path -Name 'ConsentPromptBehaviorUser').ConsentPromptBehaviorUser -eq 0) {
        Write-Log 'OK: ConsentPromptBehaviorUser=0.'
        exit 0
    }
    Write-Log 'ERROR: ConsentPromptBehaviorUser not 0 after remediation.'
    exit 1
}
catch {
    Write-Log "ERROR during remediation: $($_.Exception.Message)"
    exit 1
}

