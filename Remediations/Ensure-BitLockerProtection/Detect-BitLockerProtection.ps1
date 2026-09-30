<#
.SYNOPSIS
    Intune Remediation - Detection: Checks that BitLocker protection is ON for
    the operating system drive.

.DESCRIPTION
    Reports NON-COMPLIANT (exit 1) when the OS drive protection status is not
    "On" - this covers both a suspended protector and a fully decrypted volume.
    The remediation resumes a suspended protector; it deliberately does NOT start
    encryption from scratch on a decrypted volume (that requires TPM state and
    recovery-key escrow decisions outside this script).

.NAME
    REM-D-WIN-BitLockerProtection

.NOTES
    Context: run as SYSTEM (64-bit).
    Exit 0 = compliant, Exit 1 = non-compliant.
#>

$LogDir = 'C:\ProgramData\IntuneScripts\Logs'
$null = New-Item -ItemType Directory -Path $LogDir -Force
$Log = Join-Path $LogDir 'Detect-BitLockerProtection.log'
function Write-Log { param($m) Add-Content -Path $Log -Value ('{0} {1}' -f (Get-Date -Format u), $m); Write-Output $m }

try {
    $vol = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction Stop

    if ($vol.ProtectionStatus -eq 'On') {
        Write-Log "COMPLIANT: BitLocker protection ON for $($env:SystemDrive) (VolumeStatus: $($vol.VolumeStatus))."
        exit 0
    }

    Write-Log "NON-COMPLIANT: BitLocker protection is '$($vol.ProtectionStatus)' for $($env:SystemDrive) (VolumeStatus: $($vol.VolumeStatus))."
    exit 1
}
catch {
    Write-Log "ERROR during detection: $($_.Exception.Message)"
    exit 1
}


