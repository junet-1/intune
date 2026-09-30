<#
.SYNOPSIS
    Intune Remediation - Detection: Checks that UAC elevation requests of
    standard users are denied automatically.

.DESCRIPTION
    Reports NON-COMPLIANT (exit 1) if ConsentPromptBehaviorUser is not 0.
    Der Wert steuert "User Account Control: Behavior of the elevation prompt for
    standard users"; 0 = Automatically deny elevation requests, 1 = Prompt for
    credentials on the secure desktop, 3 (Default) = Prompt for credentials.
    Mit 0 sieht ein Standardbenutzer keinen Anmeldedialog mehr, sondern eine
    Zugriff-verweigert-Meldung - Adminkennwoerter koennen damit nicht mehr am
    Client eingegeben werden.

.NAME
    REM-D-WIN-UacDenyElevation

.NOTES
    Registry: HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System
    Context: run as SYSTEM (64-bit).
    Exit 0 = compliant, Exit 1 = non-compliant.
#>

$LogDir = 'C:\ProgramData\IntuneScripts\Logs'
$null = New-Item -ItemType Directory -Path $LogDir -Force
$Log = Join-Path $LogDir 'Detect-UACDenyElevation.log'
function Write-Log { param($m) Add-Content -Path $Log -Value ('{0} {1}' -f (Get-Date -Format u), $m); Write-Output $m }

$Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'

try {
    $val = (Get-ItemProperty -Path $Path -Name 'ConsentPromptBehaviorUser' -ErrorAction SilentlyContinue).ConsentPromptBehaviorUser
    if ($val -eq 0) {
        Write-Log 'COMPLIANT: ConsentPromptBehaviorUser=0 (elevation requests are denied).'
        exit 0
    }
    $shown = if ($null -eq $val) { 'not set' } else { $val }
    Write-Log "NON-COMPLIANT: ConsentPromptBehaviorUser=$shown (expected 0)."
    exit 1
}
catch {
    Write-Log "ERROR during detection: $($_.Exception.Message)"
    exit 1
}

