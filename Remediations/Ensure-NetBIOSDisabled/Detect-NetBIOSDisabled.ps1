<#
.SYNOPSIS
    Intune Remediation - Detection: Checks that NetBIOS over TCP/IP is disabled on
    every network interface.

.DESCRIPTION
    Reports NON-COMPLIANT (exit 1) if any interface under NetBT\Parameters\Interfaces
    has NetbiosOptions other than 2. NetBIOS name resolution (NBT-NS) is broadcast
    based and unauthenticated, which makes it the classic lever for name poisoning
    and NTLM relay. Value 0 (take the DHCP setting) counts as non-compliant too,
    because it leaves the decision to the DHCP server.

.NAME
    REM-D-WIN-NetBIOSDisabled

.NOTES
    Context: run as SYSTEM (64-bit).
    Exit 0 = compliant, Exit 1 = non-compliant.
#>

$LogDir = 'C:\ProgramData\IntuneScripts\Logs'
$null = New-Item -ItemType Directory -Path $LogDir -Force
$Log = Join-Path $LogDir 'Detect-NetBIOSDisabled.log'
function Write-Log { param($m) Add-Content -Path $Log -Value ('{0} {1}' -f (Get-Date -Format u), $m); Write-Output $m }

$Root = 'HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters\Interfaces'

try {
    $ifaces = Get-ChildItem -Path $Root -ErrorAction Stop | Where-Object { $_.PSChildName -like 'Tcpip_*' }
    if (-not $ifaces) {
        Write-Log 'COMPLIANT: no Tcpip_* interfaces present under NetBT.'
        exit 0
    }

    $bad = foreach ($i in $ifaces) {
        $val = (Get-ItemProperty -Path $i.PSPath -Name 'NetbiosOptions' -ErrorAction SilentlyContinue).NetbiosOptions
        if ($val -ne 2) { '{0}={1}' -f $i.PSChildName, $(if ($null -eq $val) { 'unset' } else { $val }) }
    }

    if ($bad) {
        Write-Log ("NON-COMPLIANT: NetBIOS over TCP/IP not disabled on {0} interface(s): {1}" -f @($bad).Count, ($bad -join ', '))
        exit 1
    }

    Write-Log ("COMPLIANT: NetBIOS over TCP/IP disabled on all {0} interface(s)." -f @($ifaces).Count)
    exit 0
}
catch {
    Write-Log "ERROR during detection: $($_.Exception.Message)"
    exit 1
}

