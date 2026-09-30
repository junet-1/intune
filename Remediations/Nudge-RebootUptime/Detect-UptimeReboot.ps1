<#
.SYNOPSIS
    Intune Remediation - Detection: Flags devices that have not been restarted for
    a while.

.DESCRIPTION
    NON-COMPLIANT (exit 1) when the system uptime exceeds the configured number of
    days. The remediation reminds the user to restart - it never forces a reboot.

.NAME
    REM-U-WIN-RebootNudge

.RUNAS
    user

.NOTES
    Runs in the USER context so the remediation can show a toast.
    Exit 0 = compliant, Exit 1 = non-compliant.
#>

#region ---- Configuration (keep identical in Detect + Remediate) ---------------
# Remind after this many days of uptime.
$MaxUptimeDays = 7
#endregion ----------------------------------------------------------------------

$LogDir = 'C:\ProgramData\IntuneScripts\Logs'
$null = New-Item -ItemType Directory -Path $LogDir -Force
$Log = Join-Path $LogDir 'Detect-UptimeReboot.log'
function Write-Log { param($m) Add-Content -Path $Log -Value ('{0} {1}' -f (Get-Date -Format u), $m); Write-Output $m }

try {
    $boot = (Get-CimInstance Win32_OperatingSystem -ErrorAction Stop).LastBootUpTime
    $days = [int]((Get-Date) - $boot).TotalDays

    if ($days -gt $MaxUptimeDays) {
        Write-Log "NON-COMPLIANT: uptime is $days days (max $MaxUptimeDays)."
        exit 1
    }
    Write-Log "COMPLIANT: uptime is $days days."
    exit 0
}
catch {
    Write-Log "ERROR during detection: $($_.Exception.Message)"
    exit 1
}

