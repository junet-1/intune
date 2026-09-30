<#
.SYNOPSIS
    Intune Platform Script: Installs fonts machine-wide.

.DESCRIPTION
    Copies every .ttf/.otf found in the source folder into the Windows Fonts
    directory and registers it for all users. Idempotent - already installed
    fonts are skipped. Runs as SYSTEM.

    Package the fonts next to this script (default subfolder ".\Fonts") when you
    upload it, or point -Source at another path.

.PARAMETER Source
    Folder holding the font files. Default: a "Fonts" subfolder next to the script.

.NAME
    PS-D-WIN-InstallFonts

.NOTES
    Assign as Platform script. Run as SYSTEM (logged-on credentials: No). 64-bit: Yes.
    Exit 0 = success, non-zero = failure.
#>

param(
    [string]$Source
)

$ErrorActionPreference = 'Stop'

$LogDir = 'C:\ProgramData\IntuneScripts\Logs'
$null = New-Item -ItemType Directory -Path $LogDir -Force
$Log = Join-Path $LogDir 'PS-D-WIN-InstallFonts.log'
function Write-Log { param($m) Add-Content -Path $Log -Value ('{0} {1}' -f (Get-Date -Format u), $m); Write-Output $m }

try {
    if (-not $Source) { $Source = Join-Path $PSScriptRoot 'Fonts' }
    if (-not (Test-Path $Source)) { Write-Log "No source folder: $Source"; exit 0 }

    $fontsDir = Join-Path $env:WINDIR 'Fonts'
    $regPath  = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'

    $installed = 0
    Get-ChildItem -Path $Source -Include *.ttf, *.otf -File -Recurse | ForEach-Object {
        $dest = Join-Path $fontsDir $_.Name
        if (Test-Path $dest) { Write-Log "Skip (present): $($_.Name)"; return }

        Copy-Item -LiteralPath $_.FullName -Destination $dest -Force

        $suffix   = if ($_.Extension -eq '.otf') { ' (OpenType)' } else { ' (TrueType)' }
        $regName  = $_.BaseName + $suffix
        New-ItemProperty -Path $regPath -Name $regName -Value $_.Name -PropertyType String -Force | Out-Null
        $installed++
        Write-Log "Installed: $($_.Name)"
    }

    Write-Log "Done. Installed $installed font(s)."
    exit 0
}
catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    exit 1
}

