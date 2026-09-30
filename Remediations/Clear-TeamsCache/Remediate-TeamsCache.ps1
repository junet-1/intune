<#
.SYNOPSIS
    Intune Remediation - Remediation: Clears the Microsoft Teams cache for the
    current user.

.DESCRIPTION
    Removes the cache folders of classic Teams and new Teams. To avoid disrupting
    an active session it does nothing while a Teams process is running - the next
    cycle cleans up once Teams is closed. Teams rebuilds the cache on next start.

.NAME
    Clear Teams Cache

.RUNAS
    user

.NOTES
    Adapted from the community EndpointAnalyticsRemediationScripts (MIT).
    Runs in the USER context. Exit 0 = success (or skipped), Exit 1 = error.
#>

$LogDir = 'C:\ProgramData\IntuneScripts\Logs'
$null = New-Item -ItemType Directory -Path $LogDir -Force
$Log = Join-Path $LogDir 'Remediate-TeamsCache.log'
function Write-Log { param($m) Add-Content -Path $Log -Value ('{0} {1}' -f (Get-Date -Format u), $m); Write-Output $m }

try {
    if (Get-Process -Name 'Teams', 'ms-teams' -ErrorAction SilentlyContinue) {
        Write-Log 'Skipped: Teams is running, not touching the cache this cycle.'
        exit 0
    }

    $removed = 0

    # Classic Teams: clear the cache-related subfolders only.
    $classic = Join-Path $env:APPDATA 'Microsoft\Teams'
    if (Test-Path $classic) {
        $subs = 'Cache', 'GPUCache', 'Code Cache', 'blob_storage', 'IndexedDB',
                'Local Storage', 'tmp', 'Service Worker', 'Application Cache'
        foreach ($s in $subs) {
            $t = Join-Path $classic $s
            if (Test-Path $t) { Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue; $removed++ }
        }
    }

    # New Teams: clear the LocalCache contents.
    $new = Join-Path $env:LOCALAPPDATA 'Packages\MSTeams_8wekyb3d8bbwe\LocalCache'
    if (Test-Path $new) {
        Get-ChildItem -LiteralPath $new -Recurse -File -Force -ErrorAction SilentlyContinue |
            Remove-Item -Force -ErrorAction SilentlyContinue
        $removed++
    }

    Write-Log "OK: Teams cache cleared ($removed location(s))."
    exit 0
}
catch {
    Write-Log "ERROR during remediation: $($_.Exception.Message)"
    exit 1
}

