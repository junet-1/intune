<#
.SYNOPSIS
    Intune Remediation - Remediation: Requires encryption for LDAP client
    sessions.

.DESCRIPTION
    Sets LDAPClientConfidentiality = 2 (Require) under
    HKLM\SYSTEM\CurrentControlSet\Services\ldap. Idempotent. Creates the key and
    value if missing. Takes effect on the next LDAP connection; no service
    restart or reboot required.

.NAME
    REM-D-WIN-LdapClientEncryption

.NOTES
    Adapted from pariswells.com ("Encrypt LDAP client traffic ... Intune").
    Context: run as SYSTEM (64-bit).
    Exit 0 = success, Exit 1 = error.
#>

$LogDir = 'C:\ProgramData\IntuneScripts\Logs'
$null = New-Item -ItemType Directory -Path $LogDir -Force
$Log = Join-Path $LogDir 'Remediate-LDAPClientEncryption.log'
function Write-Log { param($m) Add-Content -Path $Log -Value ('{0} {1}' -f (Get-Date -Format u), $m); Write-Output $m }

$Path = 'HKLM:\SYSTEM\CurrentControlSet\Services\ldap'
$Name = 'LDAPClientConfidentiality'

try {
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    New-ItemProperty -Path $Path -Name $Name -Value 2 -PropertyType DWord -Force | Out-Null
    Write-Log "Set $Name=2 at $Path"

    $val = (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue).$Name
    if ($val -ne 2) {
        Write-Log "ERROR: $Name is $val after remediation."
        exit 1
    }
    Write-Log 'OK: LDAP client encryption required.'
    exit 0
}
catch {
    Write-Log "ERROR during remediation: $($_.Exception.Message)"
    exit 1
}

