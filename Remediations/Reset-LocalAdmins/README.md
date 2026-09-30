# Remediation: Reset Local Admins (except LAPS-Admin)

Intune remediation package that enforces an allowlist on the local
**Administrators** group. All accounts that aren't allowed are removed; the
LAPS-managed admin **LAPS-Admin** is kept.

## Files

| File | Role in Intune |
|------|----------------|
| `Detect-LocalAdmins.ps1` | Detection script (exit 1 = cleanup needed) |
| `Remediate-LocalAdmins.ps1` | Remediation script (removes unauthorized admins) |

## Default allowlist

- `LAPS-Admin` (Windows LAPS account; change the name to match your LAPS policy)
- Built-in Administrator (RID 500) – lockout protection
- Entra roles (`S-1-12-1-*`, e.g. Global Administrator / Microsoft Entra Joined Device Local Administrator)
- Domain Admins / Enterprise Admins (RID 512 / 519) on domain-joined devices

Customize via the configuration block at the top of **both** scripts
(`$AllowedNames`, `$AllowedSids`, `$Keep*` switches). The block must be identical
in detection and remediation.

## Deployment in Intune

1. Intune admin center → **Devices → Scripts and remediations → Create**.
2. Detection: `Detect-LocalAdmins.ps1`, Remediation: `Remediate-LocalAdmins.ps1`.
3. **Run this script using the logged-on credentials:** `No` (SYSTEM).
4. **Enforce script signature check:** as required.
5. **Run script in 64-bit PowerShell:** `Yes`.
6. Assign a schedule (e.g. daily).

## Safety net

The remediation aborts if **no** allowed admin account would remain after the
cleanup – this prevents a complete lockout caused by a misconfigured allowlist.

## Notes

- Enumeration and removal use the ADSI/WinNT provider instead of
  `Get-LocalGroupMember`, because the latter fails with `0x80070456` on
  unresolvable Entra SIDs.
- Test on pilot devices before rollout and make sure Windows LAPS password
  rotation works.
