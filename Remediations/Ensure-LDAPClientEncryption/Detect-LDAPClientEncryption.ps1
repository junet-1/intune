<#
.SYNOPSIS
    Intune Remediation - Detection: Checks that the LDAP client requires
    encryption (sealing/TLS) for LDAP sessions.

.DESCRIPTION
    Reports NON-COMPLIANT (exit 1) if LDAPClientConfidentiality under
    HKLM\SYSTEM\CurrentControlSet\Services\ldap is not set to 2 (Require).
    Values: 0 = None, 1 = Negotiate (default), 2 = Require. Required encryption
    protects directory data in transit. The remediation sets the value to 2.

.NAME
    REM-D-WIN-LdapClientEncryption

.NOTES
    Adapted from pariswells.com ("Encrypt LDAP client traffic ... Intune").
    Evaluated by Windows 11 24H2 and later; older builds ignore the value.
    Context: run as SYSTEM (64-bit).
    Exit 0 = compliant, Exit 1 = non-compliant.
#>

$LogDir = 'C:\ProgramData\IntuneScripts\Logs'
$null = New-Item -ItemType Directory -Path $LogDir -Force
$Log = Join-Path $LogDir 'Detect-LDAPClientEncryption.log'
function Write-Log { param($m) Add-Content -Path $Log -Value ('{0} {1}' -f (Get-Date -Format u), $m); Write-Output $m }

$Path = 'HKLM:\SYSTEM\CurrentControlSet\Services\ldap'
$Name = 'LDAPClientConfidentiality'

try {
    $val = (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue).$Name

    if ($null -eq $val) {
        Write-Log "NON-COMPLIANT: $Name not set (default Negotiate)."
        exit 1
    }
    if ($val -ne 2) {
        Write-Log "NON-COMPLIANT: $Name = $val (expected 2)."
        exit 1
    }
    Write-Log "COMPLIANT: $Name = 2 (Require)."
    exit 0
}
catch {
    Write-Log "ERROR during detection: $($_.Exception.Message)"
    exit 1
}

