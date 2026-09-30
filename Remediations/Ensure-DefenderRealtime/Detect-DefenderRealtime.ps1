<#
.SYNOPSIS
    Intune Remediation - Detection: Checks that Microsoft Defender real-time
    protection is active and the antimalware signatures are reasonably fresh.

.DESCRIPTION
    Reports NON-COMPLIANT (exit 1) when Defender is the active antivirus but
    real-time monitoring is turned off, or the signatures are older than the
    configured maximum age.

    If Defender is running in passive / EDR-block / side-by-side mode (a
    third-party antivirus owns real-time protection), the device is reported
    COMPLIANT - the remediation must not fight the active product.

.NAME
    REM-D-WIN-DefenderRealtime

.NOTES
    Context: run as SYSTEM (64-bit).
    Exit 0 = compliant, Exit 1 = non-compliant.
#>

$LogDir = 'C:\ProgramData\IntuneScripts\Logs'
$null = New-Item -ItemType Directory -Path $LogDir -Force
$Log = Join-Path $LogDir 'Detect-DefenderRealtime.log'
function Write-Log { param($m) Add-Content -Path $Log -Value ('{0} {1}' -f (Get-Date -Format u), $m); Write-Output $m }

#region ---- Configuration (keep identical in Detect + Remediate) ---------------

# Non-compliant if the antimalware signatures are older than this many days.
$MaxSignatureAgeDays = 7

#endregion ----------------------------------------------------------------------

try {
    $status = Get-MpComputerStatus -ErrorAction Stop

    # Only enforce when Defender is the ACTIVE antivirus (running mode "Normal").
    if ($status.AMRunningMode -ne 'Normal') {
        Write-Log "COMPLIANT: Defender in '$($status.AMRunningMode)' mode - a third-party AV owns real-time protection."
        exit 0
    }

    $reasons = New-Object System.Collections.Generic.List[string]

    if (-not $status.RealTimeProtectionEnabled) {
        $reasons.Add('real-time protection disabled')
    }

    $pref = Get-MpPreference -ErrorAction Stop
    if ($pref.DisableRealtimeMonitoring) {
        $reasons.Add('DisableRealtimeMonitoring set')
    }

    $sigAge = (Get-Date) - $status.AntivirusSignatureLastUpdated
    if ($sigAge.TotalDays -gt $MaxSignatureAgeDays) {
        $reasons.Add("signatures $([int]$sigAge.TotalDays) days old (max $MaxSignatureAgeDays)")
    }

    if ($reasons.Count -gt 0) {
        Write-Log "NON-COMPLIANT: $($reasons -join '; ')."
        exit 1
    }

    Write-Log "COMPLIANT: Defender real-time protection on, signatures up to date."
    exit 0
}
catch {
    Write-Log "ERROR during detection: $($_.Exception.Message)"
    exit 1
}


