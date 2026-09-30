<#
.SYNOPSIS
    Intune Platform Script: Creates a shortcut (.lnk) for all users.

.DESCRIPTION
    Creates a shortcut in a common (all-users) location. Idempotent - an existing
    shortcut with the same name is overwritten. Runs as SYSTEM. Edit the param
    defaults, or deploy several copies with different values.

.PARAMETER Name
    Shortcut display name (without .lnk).

.PARAMETER TargetPath
    The executable, file or URL the shortcut points to.

.PARAMETER Location
    PublicDesktop | CommonPrograms | CommonStartMenu. Default PublicDesktop.

.PARAMETER Arguments
    Optional command-line arguments.

.PARAMETER IconLocation
    Optional icon, e.g. "C:\Path\app.exe,0".

.NAME
    PS-D-WIN-CreateShortcut

.NOTES
    Assign as Platform script. Run as SYSTEM (logged-on credentials: No). 64-bit: Yes.
    Exit 0 = success, non-zero = failure.
#>

param(
    [string]$Name         = 'IT Service Desk',
    [string]$TargetPath   = 'https://servicedesk.contoso.com',
    [ValidateSet('PublicDesktop', 'CommonPrograms', 'CommonStartMenu')]
    [string]$Location     = 'PublicDesktop',
    [string]$Arguments    = '',
    [string]$WorkingDirectory = '',
    [string]$IconLocation = ''
)

$ErrorActionPreference = 'Stop'

$LogDir = 'C:\ProgramData\IntuneScripts\Logs'
$null = New-Item -ItemType Directory -Path $LogDir -Force
$Log = Join-Path $LogDir 'PS-D-WIN-CreateShortcut.log'
function Write-Log { param($m) Add-Content -Path $Log -Value ('{0} {1}' -f (Get-Date -Format u), $m); Write-Output $m }

try {
    $base = switch ($Location) {
        'PublicDesktop'   { Join-Path $env:PUBLIC 'Desktop' }
        'CommonPrograms'  { [Environment]::GetFolderPath('CommonPrograms') }
        'CommonStartMenu' { [Environment]::GetFolderPath('CommonStartMenu') }
    }
    if (-not (Test-Path $base)) { New-Item -ItemType Directory -Path $base -Force | Out-Null }

    $lnkPath = Join-Path $base ("$Name.lnk")

    $wsh = New-Object -ComObject WScript.Shell
    $sc  = $wsh.CreateShortcut($lnkPath)
    $sc.TargetPath = $TargetPath
    if ($Arguments)        { $sc.Arguments        = $Arguments }
    if ($WorkingDirectory) { $sc.WorkingDirectory = $WorkingDirectory }
    if ($IconLocation)     { $sc.IconLocation     = $IconLocation }
    $sc.Save()

    Write-Log "Shortcut created: $lnkPath -> $TargetPath"
    exit 0
}
catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    exit 1
}

