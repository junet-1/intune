<#
.SYNOPSIS
    Intune Remediation - Remediation: Removes every account from the local
    "Administrators" group that is NOT on the allowlist.

.DESCRIPTION
    The LAPS-managed admin (LAPS-Admin) and the configured protected accounts
    (built-in Administrator, Entra roles, optionally Domain Admins) are kept.
    All other members are removed by SID via the ADSI/WinNT provider.

    The configuration block MUST be kept identical to the detection script.

.NOTES
    Context: run as SYSTEM (64-bit).
    Exit 0 = cleanup successful (or nothing to do), Exit 1 = error.
#>

$LogDir = 'C:\ProgramData\IntuneScripts\Logs'
$null = New-Item -ItemType Directory -Path $LogDir -Force
$Log = Join-Path $LogDir 'Remediate-LocalAdmins.log'
function Write-Log { param($m) Add-Content -Path $Log -Value ('{0} {1}' -f (Get-Date -Format u), $m); Write-Output $m }

#region ---- Configuration (keep identical in Detect + Remediate) ---------------

$AllowedNames = @(
    'LAPS-Admin'         # LAPS-managed local admin
)

$AllowedSids = @(
    # 'S-1-5-21-...-1234'
)

$KeepBuiltinAdministrator = $true
$KeepEntraRoleAdmins      = $true
$KeepDomainAdmins         = $true

#endregion ----------------------------------------------------------------------

function Get-AdminGroup {
    $groupSid  = New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-544')
    $groupName = $groupSid.Translate([System.Security.Principal.NTAccount]).Value.Split('\')[-1]
    return [ADSI]"WinNT://./$groupName,group"
}

function Get-AdminGroupMembers {
    param($Group)
    foreach ($m in @($Group.Invoke('Members'))) {
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
    $group   = Get-AdminGroup
    $members = @(Get-AdminGroupMembers -Group $group)
    $toRemove = @($members | Where-Object { -not (Test-Allowed $_) })

    if ($toRemove.Count -eq 0) {
        Write-Log "OK: No unauthorized local admins - nothing to remove."
        exit 0
    }

    # Safety net: if NO allowed account would remain, do NOT clean up
    # (prevents a full lockout caused by allowlist misconfiguration).
    $remaining = @($members | Where-Object { Test-Allowed $_ })
    if ($remaining.Count -eq 0) {
        Write-Log "ABORT: No allowed admin account present - cleanup skipped to avoid lockout."
        exit 1
    }

    $errors = @()
    foreach ($member in $toRemove) {
        try {
            # Removing via SID binding is the most robust (also for Entra SIDs).
            $group.Remove("WinNT://$($member.Sid)")
            Write-Log "Removed: $($member.Name) [$($member.Sid)]"
        }
        catch {
            # Fallback via the original ADsPath.
            try {
                $group.Remove($member.AdsPath)
                Write-Log "Removed (ADsPath fallback): $($member.Name) [$($member.Sid)]"
            }
            catch {
                $errors += "$($member.Name) [$($member.Sid)]: $($_.Exception.Message)"
            }
        }
    }

    if ($errors.Count -gt 0) {
        Write-Log "ERROR while removing: $($errors -join '; ')"
        exit 1
    }

    Write-Log "REMEDIATED: Removed $($toRemove.Count) unauthorized account(s)."
    exit 0
}
catch {
    Write-Log "ERROR during remediation: $($_.Exception.Message)"
    exit 1
}

