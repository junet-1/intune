<#
.SYNOPSIS
    Intune Remediation - Detection: Flags a bloated Microsoft Teams cache for the
    current user.

.DESCRIPTION
    NON-COMPLIANT (exit 1) when the combined Teams cache (classic and new Teams)
    exceeds the configured size. A large cache is the usual cause of Teams being
    slow, stuck signing in, or showing stale content. The remediation clears it -
    but only while Teams is not running.

.NAME
    REM-U-WIN-ClearTeamsCache

.RUNAS
    user

.NOTES
    Adapted from the community EndpointAnalyticsRemediationScripts (MIT).
    Runs in the USER context. Exit 0 = compliant, Exit 1 = non-compliant.
#>

#region ---- Configuration (keep identical in Detect + Remediate) ---------------
# Trigger cleanup once the Teams cache grows beyond this size (MB).
$MaxCacheMB = 500
#endregion ----------------------------------------------------------------------

$LogDir = 'C:\ProgramData\IntuneScripts\Logs'
$null = New-Item -ItemType Directory -Path $LogDir -Force
$Log = Join-Path $LogDir 'Detect-TeamsCache.log'
function Write-Log { param($m) Add-Content -Path $Log -Value ('{0} {1}' -f (Get-Date -Format u), $m); Write-Output $m }

try {
    $paths = @(
        (Join-Path $env:APPDATA 'Microsoft\Teams')
        (Join-Path $env:LOCALAPPDATA 'Packages\MSTeams_8wekyb3d8bbwe\LocalCache')
    ) | Where-Object { Test-Path $_ }

    if ($paths.Count -eq 0) {
        Write-Log 'COMPLIANT: no Teams cache present.'
        exit 0
    }

    $bytes = 0
    foreach ($p in $paths) {
        $bytes += (Get-ChildItem -LiteralPath $p -Recurse -File -Force -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum).Sum
    }
    $mb = [math]::Round($bytes / 1MB)

    if ($mb -gt $MaxCacheMB) {
        Write-Log "NON-COMPLIANT: Teams cache is $mb MB (max $MaxCacheMB)."
        exit 1
    }
    Write-Log "COMPLIANT: Teams cache is $mb MB."
    exit 0
}
catch {
    Write-Log "ERROR during detection: $($_.Exception.Message)"
    exit 1
}

