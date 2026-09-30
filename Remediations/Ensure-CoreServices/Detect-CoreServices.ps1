<#
.SYNOPSIS
    Intune Remediation - Detection: Checks that key services (Office Click-to-Run
    and Windows Update) are neither disabled nor stopped.

.DESCRIPTION
    NON-COMPLIANT (exit 1) when a monitored service is set to Disabled (when it
    should not be) or is not running (when EnsureRunning is set). Services that
    are not installed on the device are ignored. The remediation re-enables and
    starts them.

.NAME
    REM-D-WIN-CoreServices

.NOTES
    Context: run as SYSTEM (64-bit).
    Exit 0 = compliant, Exit 1 = non-compliant.
#>

#region ---- Configuration (keep identical in Detect + Remediate) ---------------
# Note: wuauserv is trigger-started and normally idles in the Stopped state by
# design. EnsureRunning = $true will therefore flag it most cycles and start it
# each time (harmless but noisy). Set EnsureRunning = $false for wuauserv to only
# guard against it being Disabled.
$Services = @(
    @{ Name = 'ClickToRunSvc'; DesiredStartType = 'Automatic'; EnsureRunning = $true }
    @{ Name = 'wuauserv';      DesiredStartType = 'Manual';    EnsureRunning = $true }
)
#endregion ----------------------------------------------------------------------

$LogDir = 'C:\ProgramData\IntuneScripts\Logs'
$null = New-Item -ItemType Directory -Path $LogDir -Force
$Log = Join-Path $LogDir 'Detect-CoreServices.log'
function Write-Log { param($m) Add-Content -Path $Log -Value ('{0} {1}' -f (Get-Date -Format u), $m); Write-Output $m }

try {
    $issues = @()
    foreach ($svc in $Services) {
        $s = Get-Service -Name $svc.Name -ErrorAction SilentlyContinue
        if (-not $s) { continue }   # not installed - nothing to enforce

        if ($s.StartType -eq 'Disabled' -and $svc.DesiredStartType -ne 'Disabled') {
            $issues += "$($svc.Name) is Disabled"
        }
        if ($svc.EnsureRunning -and $s.Status -ne 'Running') {
            $issues += "$($svc.Name) is $($s.Status)"
        }
    }

    if ($issues.Count -gt 0) {
        Write-Log "NON-COMPLIANT: $($issues -join '; ')."
        exit 1
    }
    Write-Log 'COMPLIANT: monitored services are enabled and running.'
    exit 0
}
catch {
    Write-Log "ERROR during detection: $($_.Exception.Message)"
    exit 1
}

