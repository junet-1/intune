<#
.SYNOPSIS
    Intune Platform Script: Script-shaped files open for viewing instead of running.

.DESCRIPTION
    PS-D-WIN-DefaultAppAssociations.ps1 imports the default associations through DISM, which
    only reaches profiles created afterwards - and Windows does not route every
    executable text format through the default-association store at all. This
    script closes both gaps machine-wide by rewriting the ProgIDs under
    HKLM:\SOFTWARE\Classes.

    For every ProgID below it adds a "safeview" verb pointing at Notepad++ and
    makes that verb the default. Double-click then shows the file. The original
    verb stays in place, so a deliberate run is still one right-click away, and
    calls that never touch the shell (cmd /c, wscript, powershell -File) are
    unaffected. The previous default verb is recorded under
    HKLM:\SOFTWARE\IntuneScripts\FileTypeSafety so the change can be reverted.

    The goal is the accidental double-click, not a blocked attacker. Turning off
    the Windows Script Host would go further but also breaks vbs/js callers, so
    $DisableWindowsScriptHost is off by default.

    Requires Notepad++ to be installed as a required app first.

.NAME
    PS-D-WIN-ScriptFileSafety

.RUNAS
    system

.RUN32
    false

.ENFORCESIGNATURE
    false

.NOTES
    Assign as Platform script. Run as SYSTEM (logged-on credentials: No). 64-bit: Yes.
    Takes effect immediately for all users, including existing profiles.
    A per-user choice made in "Open with > Always" still wins for that user and
    that extension.
    Exit 0 = success, 1 = Notepad++ not found or registry write failed.
#>

$ErrorActionPreference = 'Stop'

$LogDir = 'C:\ProgramData\IntuneScripts\Logs'
$null = New-Item -ItemType Directory -Path $LogDir -Force
$Log = Join-Path $LogDir 'PS-D-WIN-ScriptFileSafety.log'
function Write-Log { param($m) Add-Content -Path $Log -Value ('{0} {1}' -f (Get-Date -Format u), $m); Write-Output $m }

Write-Log '=== PS-D-WIN-ScriptFileSafety started ==='

#region Konfiguration -------------------------------------------------------------
# ProgIDs whose default action executes the file. Entries that do not exist on the
# device are skipped.
$ProgIds = @(
    'batfile'                       # .bat
    'cmdfile'                       # .cmd
    'Microsoft.PowerShellScript.1'  # .ps1
    'VBSFile'                       # .vbs
    'VBEFile'                       # .vbe
    'JSFile'                        # .js
    'JSEFile'                       # .jse
    'WSFFile'                       # .wsf
    'WSHFile'                       # .wsh
    'htafile'                       # .hta
    'regfile'                       # .reg
    'scrfile'                       # .scr
    'inffile'                       # .inf
)

$VerbKey  = 'safeview'
$VerbText = 'In Notepad++ ansehen'

$DisableWindowsScriptHost = $false
#endregion ------------------------------------------------------------------------

# ---- Notepad++ suchen ------------------------------------------------------------
$AppPathKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\notepad++.exe'
$Npp = $null
if (Test-Path $AppPathKey) {
    $Npp = (Get-ItemProperty -Path $AppPathKey).'(default)'
}
if (-not $Npp -or -not (Test-Path -LiteralPath $Npp)) {
    $Npp = @(
        "$env:ProgramFiles\Notepad++\notepad++.exe"
        "${env:ProgramFiles(x86)}\Notepad++\notepad++.exe"
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
}
if (-not $Npp) {
    Write-Log 'ERROR: notepad++.exe not found. Deploy Notepad++ as a required app first.'
    exit 1
}
Write-Log "Notepad++: $Npp"

$Command = '"{0}" "%1"' -f $Npp
$StateKey = 'HKLM:\SOFTWARE\IntuneScripts\FileTypeSafety'

try {
    if (-not (Test-Path $StateKey)) { New-Item -Path $StateKey -Force | Out-Null }

    foreach ($progId in $ProgIds) {
        $classKey = "HKLM:\SOFTWARE\Classes\$progId"
        if (-not (Test-Path $classKey)) {
            Write-Log "  $progId not present, skipped"
            continue
        }

        $shellKey = Join-Path $classKey 'shell'
        if (-not (Test-Path $shellKey)) { New-Item -Path $shellKey -Force | Out-Null }

        # Remember the verb that was default before the first run, once.
        $previous = (Get-ItemProperty -Path $StateKey -ErrorAction SilentlyContinue).$progId
        if ($null -eq $previous) {
            $current = (Get-ItemProperty -Path $shellKey -ErrorAction SilentlyContinue).'(default)'
            if ([string]::IsNullOrWhiteSpace($current)) { $current = 'open' }
            New-ItemProperty -Path $StateKey -Name $progId -Value $current -PropertyType String -Force | Out-Null
            Write-Log "  $progId previous default verb: $current"
        }

        $verbPath = Join-Path $shellKey $VerbKey
        if (-not (Test-Path $verbPath)) { New-Item -Path $verbPath -Force | Out-Null }
        Set-ItemProperty -Path $verbPath -Name '(default)' -Value $VerbText

        $cmdPath = Join-Path $verbPath 'command'
        if (-not (Test-Path $cmdPath)) { New-Item -Path $cmdPath -Force | Out-Null }
        Set-ItemProperty -Path $cmdPath -Name '(default)' -Value $Command

        Set-ItemProperty -Path $shellKey -Name '(default)' -Value $VerbKey
        Write-Log "  $progId -> default verb $VerbKey"
    }

    # ---- Windows Script Host -----------------------------------------------------
    if ($DisableWindowsScriptHost) {
        $wshKey = 'HKLM:\SOFTWARE\Microsoft\Windows Script Host\Settings'
        if (-not (Test-Path $wshKey)) { New-Item -Path $wshKey -Force | Out-Null }
        New-ItemProperty -Path $wshKey -Name 'Enabled' -Value 0 -PropertyType DWord -Force | Out-Null
        # 32-bit view of the same setting - cscript/wscript from SysWOW64 read it there.
        & reg.exe add 'HKLM\SOFTWARE\Microsoft\Windows Script Host\Settings' /v Enabled /t REG_DWORD /d 0 /f /reg:32 2>&1 | Out-Null
        Write-Log '  Windows Script Host disabled (Enabled = 0, 64-bit and 32-bit view)'
    }
    else {
        Write-Log '  Windows Script Host left untouched ($DisableWindowsScriptHost = $false)'
    }

    Write-Log '=== Finished ==='
    exit 0
}
catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    exit 1
}

