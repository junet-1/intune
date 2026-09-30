<#
.SYNOPSIS
    Intune Remediation - Detection: Checks the members of the local
    "Administrators" group against an allowlist.

.DESCRIPTION
    Reports NON-COMPLIANT (exit 1) as soon as an account is found in the local
    Administrators group that is NOT on the allowlist. The LAPS-managed admin
    (LAPS-Admin) and the defined protected accounts are kept. The actual cleanup
    is done by the remediation script.

    Enumeration deliberately uses the ADSI/WinNT provider (not
    Get-LocalGroupMember), because the latter fails with "Failed to compare two
    elements in the array" (0x80070456) when unresolvable Entra SIDs are present.

.NAME
    REM-D-WIN-ResetLocalAdmins

.NOTES
    Context: run as SYSTEM (64-bit).
    Exit 0 = compliant, Exit 1 = non-compliant.
#>

$LogDir = 'C:\ProgramData\IntuneScripts\Logs'
$null = New-Item -ItemType Directory -Path $LogDir -Force
$Log = Join-Path $LogDir 'Detect-LocalAdmins.log'
function Write-Log { param($m) Add-Content -Path $Log -Value ('{0} {1}' -f (Get-Date -Format u), $m); Write-Output $m }

#region ---- Configuration (keep identical in Detect + Remediate) ---------------

# LAPS admin and any other accounts that are ALWAYS allowed to be local admin
# (by name). Comparison is case-insensitive.
$AllowedNames = @(
    'LAPS-Admin'         # LAPS-managed local admin
)

# Additional allowed accounts by SID (e.g. specific service accounts).
$AllowedSids = @(
    # 'S-1-5-21-...-1234'
)

# Keep the built-in Administrator account (RID 500) to avoid lockout.
$KeepBuiltinAdministrator = $true

# Keep Entra ID roles (Global Admin / "Azure AD Joined Device Local
# Administrator"). These are added as SIDs with the prefix "S-1-12-1-".
$KeepEntraRoleAdmins = $true

# Keep domain groups "Domain Admins" (RID 512) / "Enterprise Admins" (519)
# on domain-joined devices.
$KeepDomainAdmins = $true

#endregion ----------------------------------------------------------------------

function Get-AdminGroupMembers {
    # Resolve the local Administrators group reliably via its well-known SID.
    $groupSid  = New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-544')
    $groupName = $groupSid.Translate([System.Security.Principal.NTAccount]).Value.Split('\')[-1]
    $group     = [ADSI]"WinNT://./$groupName,group"

    foreach ($m in @($group.Invoke('Members'))) {
        $adsPath  = $m.GetType().InvokeMember('ADsPath',   'GetProperty', $null, $m, $null)
        $name     = $m.GetType().InvokeMember('Name',      'GetProperty', $null, $m, $null)
        $sidBytes = $m.GetType().InvokeMember('objectSID', 'GetProperty', $null, $m, $null)
        $sid = (New-Object System.Security.Principal.SecurityIdentifier(([byte[]]$sidBytes), 0)).Value

        [pscustomobject]@{
            Name    = $name
            Sid     = $sid
            AdsPath = $adsPath
        }
    }
}

function Test-Allowed {
    param([pscustomobject]$Member)

    if ($AllowedNames -contains $Member.Name)          { return $true }
    if ($AllowedSids  -contains $Member.Sid)           { return $true }
    if ($KeepBuiltinAdministrator -and $Member.Sid -like '*-500') { return $true }
    if ($KeepEntraRoleAdmins     -and $Member.Sid -like 'S-1-12-1-*') { return $true }
    if ($KeepDomainAdmins) {
        if ($Member.Sid -like '*-512' -or $Member.Sid -like '*-519') { return $true }
    }
    return $false
}

try {
    $members = @(Get-AdminGroupMembers)
    $violations = @($members | Where-Object { -not (Test-Allowed $_) })

    if ($violations.Count -gt 0) {
        $list = ($violations | ForEach-Object { "$($_.Name) [$($_.Sid)]" }) -join '; '
        Write-Log "NON-COMPLIANT: Unauthorized local admins found: $list"
        exit 1
    }

    Write-Log "COMPLIANT: Only allowed accounts in the local Administrators group."
    exit 0
}
catch {
    # On error report non-compliant so remediation kicks in / becomes visible.
    Write-Log "ERROR during detection: $($_.Exception.Message)"
    exit 1
}

