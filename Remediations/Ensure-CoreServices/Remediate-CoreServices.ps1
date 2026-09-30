<#
.SYNOPSIS
    Intune Remediation - Remediation: Re-enables and starts the monitored
    services (Office Click-to-Run and Windows Update).

.DESCRIPTION
    For each configured service that exists: if it is Disabled it is set back to
    the desired start type, and if EnsureRunning is set and it is not running it
    is started. Idempotent. The configuration block MUST match the detection
    script.

.NAME
    Core Services Running

.NOTES
    Context: run as SYSTEM (64-bit).
    Exit 0 = success (or nothing to do), Exit 1 = error.
#>

#region ---- Configuration (keep identical in Detect + Remediate) ---------------
$Services = @(
    @{ Name = 'ClickToRunSvc'; DesiredStartType = 'Automatic'; EnsureRunning = $true }
    @{ Name = 'wuauserv';      DesiredStartType = 'Manual';    EnsureRunning = $true }
)
#endregion ----------------------------------------------------------------------

$LogDir = 'C:\ProgramData\IntuneScripts\Logs'
$null = New-Item -ItemType Directory -Path $LogDir -Force
$Log = Join-Path $LogDir 'Remediate-CoreServices.log'
function Write-Log { param($m) Add-Content -Path $Log -Value ('{0} {1}' -f (Get-Date -Format u), $m); Write-Output $m }

try {
    $errors = @()
    foreach ($svc in $Services) {
        $s = Get-Service -Name $svc.Name -ErrorAction SilentlyContinue
        if (-not $s) { Write-Log "Skip: $($svc.Name) not installed."; continue }

        if ($s.StartType -eq 'Disabled' -and $svc.DesiredStartType -ne 'Disabled') {
            try {
                Set-Service -Name $svc.Name -StartupType $svc.DesiredStartType -ErrorAction Stop
                Write-Log "Set $($svc.Name) start type to $($svc.DesiredStartType)."
            }
            catch { $errors += "$($svc.Name) start type: $($_.Exception.Message)" }
        }

        if ($svc.EnsureRunning -and (Get-Service -Name $svc.Name).Status -ne 'Running') {
            try {
                Start-Service -Name $svc.Name -ErrorAction Stop
                Write-Log "Started $($svc.Name)."
            }
            catch { $errors += "$($svc.Name) start: $($_.Exception.Message)" }
        }
    }

    if ($errors.Count -gt 0) {
        Write-Log "ERROR: $($errors -join '; ')."
        exit 1
    }
    Write-Log 'OK: monitored services enabled and running.'
    exit 0
}
catch {
    Write-Log "ERROR during remediation: $($_.Exception.Message)"
    exit 1
}

