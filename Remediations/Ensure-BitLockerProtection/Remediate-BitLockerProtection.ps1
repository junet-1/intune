<#
.SYNOPSIS
    Intune Remediation - Remediation: Resumes a suspended BitLocker protector on
    the operating system drive.

.DESCRIPTION
    If protection is suspended but the volume is (fully or partly) encrypted and
    has key protectors, Resume-BitLocker turns protection back on. A fully
    decrypted volume is left untouched and reported as an error, because starting
    encryption unattended needs TPM/recovery-key policy that lives in a dedicated
    encryption profile, not in this remediation.

.NOTES
    Context: run as SYSTEM (64-bit).
    Exit 0 = success (or nothing to do), Exit 1 = could not remediate / error.
#>

$LogDir = 'C:\ProgramData\IntuneScripts\Logs'
$null = New-Item -ItemType Directory -Path $LogDir -Force
$Log = Join-Path $LogDir 'Remediate-BitLockerProtection.log'
function Write-Log { param($m) Add-Content -Path $Log -Value ('{0} {1}' -f (Get-Date -Format u), $m); Write-Output $m }

try {
    $vol = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction Stop

    if ($vol.ProtectionStatus -eq 'On') {
        Write-Log "Nothing to do: BitLocker protection already ON for $($env:SystemDrive)."
        exit 0
    }

    $encrypted    = $vol.VolumeStatus -in @('FullyEncrypted', 'EncryptionInProgress')
    $hasProtector = @($vol.KeyProtector).Count -gt 0

    if ($encrypted -and $hasProtector) {
        Resume-BitLocker -MountPoint $env:SystemDrive -ErrorAction Stop
        $after = Get-BitLockerVolume -MountPoint $env:SystemDrive
        if ($after.ProtectionStatus -eq 'On') {
            Write-Log "OK: BitLocker protection resumed for $($env:SystemDrive)."
            exit 0
        }
        Write-Log "ERROR: protection still '$($after.ProtectionStatus)' after Resume-BitLocker."
        exit 1
    }

    Write-Log "CANNOT REMEDIATE: $($env:SystemDrive) is '$($vol.VolumeStatus)' with $(@($vol.KeyProtector).Count) protector(s) - enable encryption via the BitLocker/encryption policy."
    exit 1
}
catch {
    Write-Log "ERROR during remediation: $($_.Exception.Message)"
    exit 1
}


