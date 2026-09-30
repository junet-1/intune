<#
.SYNOPSIS
    Intune Platform Script: Writes OEM branding and the registered owner.

.DESCRIPTION
    Fills the manufacturer, model, support hours, support URL and logo shown under
    Settings > System > About, plus the registered owner and organization. The logo
    bitmap is embedded as Base64, so the script is self-contained; leave $LogoB64 empty to skip it. Runs as SYSTEM.

.NAME
    PS-D-WIN-OemBranding

.RUNAS
    system

.RUN32
    false

.ENFORCESIGNATURE
    false

.NOTES
    Assign as Platform script. Run as SYSTEM (logged-on credentials: No). 64-bit: Yes.
    The logo has to be a BMP; Windows shows it at about 120x120 pixels.
    Exit 0 = success.
#>

$ErrorActionPreference = 'Stop'

$Manufacturer = 'Contoso IT'
$Model = 'PC'
$SupportHours = 'Mon-Fri 8-16'
$SupportUrl = 'https://support.contoso.com'
$RegisteredOwner = 'Contoso'
$RegisteredOrganization = 'Contoso'
$LogoFile = 'C:\Windows\OemLogo.bmp'

$OemKey = 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation'
$NtKey = 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion'

$LogDir = 'C:\ProgramData\IntuneScripts\Logs'
$null = New-Item -ItemType Directory -Path $LogDir -Force
$Log = Join-Path $LogDir 'PS-D-WIN-OemBranding.log'
function Write-Log { param($m) Add-Content -Path $Log -Value ('{0} {1}' -f (Get-Date -Format u), $m); Write-Output $m }

Write-Log '=== PS-D-WIN-OemBranding started ==='

# ---- Embedded logo bitmap (Base64) --------------------------------------------
$LogoB64 = @'
<paste Base64 of your BMP logo here, or leave empty to skip the logo>
'@

$LogoB64 = $LogoB64 -replace '\s', ''
if ($LogoB64 -match '^[A-Za-z0-9+/=]+$') {
    [IO.File]::WriteAllBytes($LogoFile, [Convert]::FromBase64String($LogoB64))
    Write-Log ("Wrote {0:N0} bytes to {1}" -f (Get-Item $LogoFile).Length, $LogoFile)
}
else {
    Write-Log 'No logo embedded - skipping logo.'
    $LogoFile = $null
}

# ---- OEM information -----------------------------------------------------------
# reg.exe /reg:64 so the values land in the 64-bit view even if Intune runs this
# script in the 32-bit host.
$oem = [ordered]@{
    Manufacturer = $Manufacturer
    Model        = $Model
    SupportHours = $SupportHours
    SupportURL   = $SupportUrl
}
if ($LogoFile) { $oem['Logo'] = $LogoFile }

foreach ($name in $oem.Keys) {
    & reg.exe add $OemKey /v $name /t REG_SZ /d $oem[$name] /f /reg:64 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { Write-Log "  set $name = $($oem[$name])" }
    else { Write-Log "  FAILED to set $name (exit $LASTEXITCODE)" }
}

# ---- Registered owner and organization -----------------------------------------
$reg = [ordered]@{
    RegisteredOwner        = $RegisteredOwner
    RegisteredOrganization = $RegisteredOrganization
}

foreach ($name in $reg.Keys) {
    & reg.exe add $NtKey /v $name /t REG_SZ /d $reg[$name] /f /reg:64 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { Write-Log "  set $name = $($reg[$name])" }
    else { Write-Log "  FAILED to set $name (exit $LASTEXITCODE)" }
}

Write-Log '=== Finished ==='
exit 0

