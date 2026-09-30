<#
.SYNOPSIS
    Intune Platform Script: Ensures automatic acceptance of SSO permissions.

.DESCRIPTION
    Checks AutoAcceptSsoPermission under the machine-wide Windows AAD policy.
    If the value is missing, has the wrong type, or is not set to 1, the script
    creates or corrects it as a DWORD and verifies the result. Idempotent. Runs
    as SYSTEM.

.NAME
    PS-D-WIN-AutoAcceptSSO

.RUNAS
    system

.RUN32
    false

.ENFORCESIGNATURE
    true

.NOTES
    Assign as Platform script. Run as SYSTEM (logged-on credentials: No). 64-bit: Yes.
    Exit 0 = configured or already compliant, non-zero = failure (Intune retries).
#>

$ErrorActionPreference = 'Stop'

$RegPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AAD'
$ValueName = 'AutoAcceptSsoPermission'
$ExpectedValue = 1

$LogDir = 'C:\ProgramData\IntuneScripts\Logs'
$null = New-Item -ItemType Directory -Path $LogDir -Force
$Log = Join-Path $LogDir 'PS-D-WIN-AutoAcceptSSO.log'
function Write-Log { param($m) Add-Content -Path $Log -Value ('{0} {1}' -f (Get-Date -Format u), $m); Write-Output $m }

try {
    $isConfigured = $false

    if (Test-Path -Path $RegPath) {
        try {
            $key = Get-Item -Path $RegPath -ErrorAction Stop
            $currentValue = $key.GetValue($ValueName, $null)
            $currentKind = $key.GetValueKind($ValueName)
            $isConfigured = ($currentValue -eq $ExpectedValue -and $currentKind -eq [Microsoft.Win32.RegistryValueKind]::DWord)

            if (-not $isConfigured) {
                Write-Log "Current value requires correction: $ValueName=$currentValue, type=$currentKind."
            }
        }
        catch [System.ArgumentException] {
            Write-Log "$ValueName is missing and will be created."
        }
    }

    if ($isConfigured) {
        Write-Log "Already configured: $ValueName=$ExpectedValue (DWORD)."
        exit 0
    }

    if (-not (Test-Path -Path $RegPath)) {
        $null = New-Item -Path $RegPath -Force -ErrorAction Stop
        Write-Log "Created registry key $RegPath."
    }

    $null = New-ItemProperty -Path $RegPath -Name $ValueName -Value $ExpectedValue `
        -PropertyType DWord -Force -ErrorAction Stop

    $verifyKey = Get-Item -Path $RegPath -ErrorAction Stop
    $verifiedValue = $verifyKey.GetValue($ValueName, $null)
    $verifiedKind = $verifyKey.GetValueKind($ValueName)

    if ($verifiedValue -ne $ExpectedValue -or $verifiedKind -ne [Microsoft.Win32.RegistryValueKind]::DWord) {
        throw "Verification failed: $ValueName=$verifiedValue, type=$verifiedKind."
    }

    Write-Log "Configured and verified: $ValueName=$ExpectedValue (DWORD)."
    exit 0
}
catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    exit 1
}

