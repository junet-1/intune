<#
.SYNOPSIS
    Intune Remediation - Remediation: Re-enables Microsoft Defender real-time
    protection and refreshes the antimalware signatures.

.DESCRIPTION
    Turns real-time monitoring back on and, if the signatures are older than the
    configured maximum age, triggers a signature update. When Defender runs in
    passive / EDR-block / side-by-side mode (a third-party antivirus is active),
    nothing is changed.

    The configuration block MUST match the detection script.

.NOTES
    Context: run as SYSTEM (64-bit).
    Exit 0 = success (or nothing to do), Exit 1 = error.
#>

$LogDir = 'C:\ProgramData\IntuneScripts\Logs'
$null = New-Item -ItemType Directory -Path $LogDir -Force
$Log = Join-Path $LogDir 'Remediate-DefenderRealtime.log'
function Write-Log { param($m) Add-Content -Path $Log -Value ('{0} {1}' -f (Get-Date -Format u), $m); Write-Output $m }

#region ---- Configuration (keep identical in Detect + Remediate) ---------------

$MaxSignatureAgeDays = 7

#endregion ----------------------------------------------------------------------

try {
    $status = Get-MpComputerStatus -ErrorAction Stop

    if ($status.AMRunningMode -ne 'Normal') {
        Write-Log "Nothing to do: Defender in '$($status.AMRunningMode)' mode (third-party AV active)."
        exit 0
    }

    # Re-enable real-time monitoring.
    Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction Stop

    # Refresh signatures if they are stale (best effort - a failed update must not
    # mask the successful real-time toggle).
    $sigAge = (Get-Date) - $status.AntivirusSignatureLastUpdated
    if ($sigAge.TotalDays -gt $MaxSignatureAgeDays) {
        try { Update-MpSignature -ErrorAction Stop }
        catch { Write-Log "WARN: signature update failed: $($_.Exception.Message)" }
    }

    $after = Get-MpComputerStatus
    if (-not $after.RealTimeProtectionEnabled) {
        Write-Log "ERROR: real-time protection still disabled after remediation."
        exit 1
    }

    Write-Log "OK: Defender real-time protection enabled."
    exit 0
}
catch {
    Write-Log "ERROR during remediation: $($_.Exception.Message)"
    exit 1
}


