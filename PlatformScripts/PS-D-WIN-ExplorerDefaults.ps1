<#
.SYNOPSIS
    Intune Platform Script: Applies Explorer / UX defaults for every user -
    current profiles and all future ones.

.DESCRIPTION
    Writes a small set of HKCU-relative Explorer settings into the Default user
    hive (so new users inherit them) and into every currently loaded user hive.
    Idempotent. Runs as SYSTEM.

    Default settings: show file extensions, open Explorer to "This PC".
    Edit the $Settings block to change or extend them.

.NAME
    PS-D-WIN-ExplorerDefaults

.NOTES
    Assign as Platform script. Run as SYSTEM (logged-on credentials: No). 64-bit: Yes.
    A logged-on user must sign out / in (or restart Explorer) to see the change.
    Exit 0 = success, non-zero = failure.
#>

$ErrorActionPreference = 'Stop'

$LogDir = 'C:\ProgramData\IntuneScripts\Logs'
$null = New-Item -ItemType Directory -Path $LogDir -Force
$Log = Join-Path $LogDir 'PS-D-WIN-ExplorerDefaults.log'
function Write-Log { param($m) Add-Content -Path $Log -Value ('{0} {1}' -f (Get-Date -Format u), $m); Write-Output $m }

#region ---- Settings (HKCU-relative) -------------------------------------------
$Settings = @(
    @{ Path = 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'HideFileExt'; Value = 0; Type = 'DWord' }  # show extensions
    @{ Path = 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'LaunchTo';    Value = 1; Type = 'DWord' }  # open to This PC
)
#endregion ----------------------------------------------------------------------

function Set-InHive {
    param([string]$HiveRoot)   # e.g. HKU:\S-1-5-21-...
    foreach ($s in $Settings) {
        $key = Join-Path $HiveRoot $s.Path
        if (-not (Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
        New-ItemProperty -Path $key -Name $s.Name -Value $s.Value -PropertyType $s.Type -Force | Out-Null
    }
}

try {
    if (-not (Get-PSDrive -Name HKU -ErrorAction SilentlyContinue)) {
        New-PSDrive -Name HKU -PSProvider Registry -Root HKEY_USERS | Out-Null
    }

    $applied = 0

    # Default profile -> future users.
    $defaultDat   = Join-Path $env:SystemDrive 'Users\Default\NTUSER.DAT'
    $loadedDefault = $false
    if (Test-Path $defaultDat) {
        & reg.exe load 'HKU\TempDefault' $defaultDat *> $null
        if ($LASTEXITCODE -eq 0) {
            $loadedDefault = $true
            Set-InHive 'HKU:\TempDefault'
            $applied++
            Write-Log 'Applied to Default profile.'
        } else {
            Write-Log 'WARN: could not load Default user hive.'
        }
    }

    # All currently loaded real user hives (SID S-1-5-21-...).
    Get-ChildItem 'HKU:\' | Where-Object { $_.PSChildName -match '^S-1-5-21-[\d-]+$' } | ForEach-Object {
        Set-InHive ('HKU:\' + $_.PSChildName)
        $applied++
        Write-Log ('Applied to ' + $_.PSChildName)
    }

    if ($loadedDefault) {
        [gc]::Collect(); Start-Sleep -Milliseconds 500
        & reg.exe unload 'HKU\TempDefault' *> $null
    }

    Write-Log "Done. Applied to $applied hive(s)."
    exit 0
}
catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    exit 1
}

