<#
.SYNOPSIS
    Intune Remediation - Remediation: Enables Windows Defender Firewall for all
    three profiles (Domain, Private, Public).

.DESCRIPTION
    Sets Enabled = True on every firewall profile that is currently off. Only the
    per-profile on/off switch is changed - inbound/outbound rules and any other
    firewall settings stay as they are.

.NOTES
    Context: run as SYSTEM (64-bit).
    Exit 0 = success (or nothing to do), Exit 1 = error.
#>

$LogDir = 'C:\ProgramData\IntuneScripts\Logs'
$null = New-Item -ItemType Directory -Path $LogDir -Force
$Log = Join-Path $LogDir 'Remediate-FirewallEnabled.log'
function Write-Log { param($m) Add-Content -Path $Log -Value ('{0} {1}' -f (Get-Date -Format u), $m); Write-Output $m }

try {
    $disabled = @(Get-NetFirewallProfile -ErrorAction Stop | Where-Object { -not $_.Enabled })

    if ($disabled.Count -eq 0) {
        Write-Log "Nothing to do: all firewall profiles already enabled."
        exit 0
    }

    Set-NetFirewallProfile -All -Enabled True -ErrorAction Stop

    $still = @(Get-NetFirewallProfile | Where-Object { -not $_.Enabled })
    if ($still.Count -gt 0) {
        $list = ($still | ForEach-Object { $_.Name }) -join ', '
        Write-Log "ERROR: Profile(s) still disabled after remediation: $list"
        exit 1
    }

    Write-Log "OK: Firewall enabled for all profiles."
    exit 0
}
catch {
    Write-Log "ERROR during remediation: $($_.Exception.Message)"
    exit 1
}


