<#
.SYNOPSIS
    Intune Remediation - Remediation: Disables NetBIOS over TCP/IP on every network
    interface.

.DESCRIPTION
    Sets NetbiosOptions = 2 on every Tcpip_* interface under NetBT\Parameters\Interfaces.
    Idempotent. Existing bindings keep their current state until the adapter is reset
    or the device restarts; new and reconnected adapters pick the value up immediately.

.NAME
    REM-D-WIN-NetBIOSDisabled

.NOTES
    Context: run as SYSTEM (64-bit).
    Exit 0 = success, Exit 1 = error.
#>

$LogDir = 'C:\ProgramData\IntuneScripts\Logs'
$null = New-Item -ItemType Directory -Path $LogDir -Force
$Log = Join-Path $LogDir 'Remediate-NetBIOSDisabled.log'
function Write-Log { param($m) Add-Content -Path $Log -Value ('{0} {1}' -f (Get-Date -Format u), $m); Write-Output $m }

$Root = 'HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters\Interfaces'

try {
    $ifaces = Get-ChildItem -Path $Root -ErrorAction Stop | Where-Object { $_.PSChildName -like 'Tcpip_*' }
    if (-not $ifaces) {
        Write-Log 'OK: no Tcpip_* interfaces present, nothing to change.'
        exit 0
    }

    $changed = 0
    foreach ($i in $ifaces) {
        $val = (Get-ItemProperty -Path $i.PSPath -Name 'NetbiosOptions' -ErrorAction SilentlyContinue).NetbiosOptions
        if ($val -ne 2) {
            New-ItemProperty -Path $i.PSPath -Name 'NetbiosOptions' -Value 2 -PropertyType DWord -Force | Out-Null
            Write-Log ("Set NetbiosOptions=2 on {0} (was {1})." -f $i.PSChildName, $(if ($null -eq $val) { 'unset' } else { $val }))
            $changed++
        }
    }

    $remaining = foreach ($i in $ifaces) {
        if ((Get-ItemProperty -Path $i.PSPath -Name 'NetbiosOptions' -ErrorAction SilentlyContinue).NetbiosOptions -ne 2) { $i.PSChildName }
    }
    if ($remaining) {
        Write-Log ("ERROR: NetbiosOptions still not 2 on: {0}" -f ($remaining -join ', '))
        exit 1
    }

    Write-Log ("OK: NetBIOS over TCP/IP disabled on all {0} interface(s), {1} changed." -f @($ifaces).Count, $changed)
    exit 0
}
catch {
    Write-Log "ERROR during remediation: $($_.Exception.Message)"
    exit 1
}

