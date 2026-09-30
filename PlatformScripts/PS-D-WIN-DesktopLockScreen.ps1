<#
.SYNOPSIS
    Intune Platform Script: Sets the corporate desktop background and lock screen image.

.DESCRIPTION
    Writes the Personalization CSP values under HKLM so the image applies to every
    profile created on the device. The image is downloaded once to local storage and
    the policy points at that copy, so later profile creations do not depend on the
    blob being reachable. If the download fails the remote URL is written instead and
    Windows fetches the image itself.

    Setting these values also prevents users from changing the background and lock
    screen - that is inherent to the Personalization CSP, not a side effect of this
    script. Requires Windows Enterprise or Education. Runs as SYSTEM.

.NAME
    PS-D-WIN-DesktopLockScreen

.RUNAS
    system

.RUN32
    false

.ENFORCESIGNATURE
    false

.NOTES
    Assign as Platform script. Run as SYSTEM (logged-on credentials: No). 64-bit: Yes.
    Applies at the next sign-in, not to an already active session.
    Exit 0 = success, non-zero = failure.
#>

$ErrorActionPreference = 'Stop'

$ImageUrl = 'https://example.com/wallpaper.png'
$ImageDir = 'C:\ProgramData\IntuneScripts\Branding'
$ImageFile = Join-Path $ImageDir 'wallpaper.png'
$RegKey = 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP'

$LogDir = 'C:\ProgramData\IntuneScripts\Logs'
$null = New-Item -ItemType Directory -Path $LogDir -Force
$Log = Join-Path $LogDir 'PS-D-WIN-DesktopLockScreen.log'
function Write-Log { param($m) Add-Content -Path $Log -Value ('{0} {1}' -f (Get-Date -Format u), $m); Write-Output $m }

Write-Log '=== PS-D-WIN-DesktopLockScreen started ==='

# ---- Download the image -------------------------------------------------------
$null = New-Item -ItemType Directory -Path $ImageDir -Force
$target = $ImageFile

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $tmp = Join-Path $env:TEMP ('bg-{0}.tmp' -f [guid]::NewGuid())
    Invoke-WebRequest -Uri $ImageUrl -OutFile $tmp -UseBasicParsing -TimeoutSec 60

    $size = (Get-Item $tmp).Length
    if ($size -lt 1024) { throw "downloaded file is only $size bytes, that is not an image" }

    Move-Item -Path $tmp -Destination $ImageFile -Force
    Write-Log ("Downloaded {0} ({1:N0} bytes) to {2}" -f $ImageUrl, $size, $ImageFile)
} catch {
    Write-Log "Download failed: $($_.Exception.Message)"
    Write-Log 'Falling back to the remote URL - Windows will fetch the image itself.'
    $target = $ImageUrl
    Remove-Item -Path $tmp -Force -ErrorAction SilentlyContinue
}

# ---- Make the image readable for every user -----------------------------------
# The personalization engine reads the file in the user's context. Without read
# access it silently falls back to the default wallpaper.
try {
    $acl = Get-Acl $ImageFile
    $sid = [Security.Principal.SecurityIdentifier]'S-1-5-32-545'   # BUILTIN\Users
    $rule = New-Object Security.AccessControl.FileSystemAccessRule($sid, 'Read', 'Allow')
    $acl.AddAccessRule($rule)
    Set-Acl -Path $ImageFile -AclObject $acl
    Write-Log '  granted BUILTIN\Users read access to the image'
} catch {
    Write-Log "  WARNING: could not set ACL: $($_.Exception.Message)"
}

# ---- Write the Personalization CSP values -------------------------------------
# reg.exe /reg:64 is used deliberately: Intune may run this script in the 32-bit
# host, in which case HKLM:\SOFTWARE would silently redirect to WOW6432Node and
# the engine - which reads the 64-bit view - would never see these values.
$values = [ordered]@{
    DesktopImagePath      = @('REG_SZ', $target)
    DesktopImageUrl       = @('REG_SZ', $target)
    DesktopImageStatus    = @('REG_DWORD', '1')
    LockScreenImagePath   = @('REG_SZ', $target)
    LockScreenImageUrl    = @('REG_SZ', $target)
    LockScreenImageStatus = @('REG_DWORD', '1')
}

foreach ($name in $values.Keys) {
    $type, $data = $values[$name]
    & reg.exe add $RegKey /v $name /t $type /d $data /f /reg:64 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Log "  FAILED to set $name (exit $LASTEXITCODE)" }
    else { Write-Log "  set $name = $data" }
}

# ---- Disable Windows Spotlight for the desktop --------------------------------
# Spotlight overrides the configured image, so it has to be off for this to show.
# Machine scope so it does not depend on the default user hive.
& reg.exe add 'HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent' /v DisableSpotlightCollectionOnDesktop /t REG_DWORD /d 1 /f /reg:64 2>&1 | Out-Null
& reg.exe add 'HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent' /v DisableWindowsSpotlightFeatures /t REG_DWORD /d 1 /f /reg:64 2>&1 | Out-Null
Write-Log '  disabled Windows Spotlight on the desktop'

# ---- Verify what actually landed in the 64-bit view ---------------------------
$check = (& reg.exe query $RegKey /v DesktopImagePath /reg:64 2>&1 | Out-String).Trim()
Write-Log "Verification: $check"

# ---- Refresh so an already active session picks it up -------------------------
& rundll32.exe user32.dll, UpdatePerUserSystemParameters 1, True

Write-Log "=== Finished. Image source: $target ==="
exit 0

