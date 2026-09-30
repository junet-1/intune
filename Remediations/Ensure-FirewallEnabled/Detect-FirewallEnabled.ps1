<#
.SYNOPSIS
    Intune Remediation - Detection: Verifies that Windows Defender Firewall is
    enabled for all three profiles (Domain, Private, Public).

.DESCRIPTION
    Reports NON-COMPLIANT (exit 1) as soon as at least one firewall profile is
    turned off. The remediation script re-enables every disabled profile; the
    firewall rules themselves are never touched.

.NAME
    REM-D-WIN-FirewallEnabled

.NOTES
    Context: run as SYSTEM (64-bit).
    Exit 0 = compliant, Exit 1 = non-compliant.
#>

$LogDir = 'C:\ProgramData\IntuneScripts\Logs'
$null = New-Item -ItemType Directory -Path $LogDir -Force
$Log = Join-Path $LogDir 'Detect-FirewallEnabled.log'
function Write-Log { param($m) Add-Content -Path $Log -Value ('{0} {1}' -f (Get-Date -Format u), $m); Write-Output $m }

try {
    $profiles = Get-NetFirewallProfile -ErrorAction Stop
    $disabled = @($profiles | Where-Object { -not $_.Enabled })

    if ($disabled.Count -gt 0) {
        $list = ($disabled | ForEach-Object { $_.Name }) -join ', '
        Write-Log "NON-COMPLIANT: Firewall disabled for profile(s): $list"
        exit 1
    }

    Write-Log "COMPLIANT: Firewall enabled for all profiles (Domain, Private, Public)."
    exit 0
}
catch {
    # Report non-compliant on error so the remediation becomes visible.
    Write-Log "ERROR during detection: $($_.Exception.Message)"
    exit 1
}


