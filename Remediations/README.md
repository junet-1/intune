# Remediations

Microsoft Intune Remediations for Windows 11 devices. Each remediation lives in its own directory and normally contains:

- `Detect-*.ps1` — exits `0` when compliant and `1` when remediation is required or detection cannot safely determine compliance.
- `Remediate-*.ps1` — applies the correction and exits non-zero on failure.
- `README.md` — deployment notes, behavior and configuration for that remediation.

## Included remediations

| Remediation | Purpose |
|---|---|
| `Clear-TeamsCache` | Clears Teams cache when the configured condition is met |
| `Ensure-BitLockerProtection` | Checks and restores BitLocker protection |
| `Ensure-CoreServices` | Ensures required Windows services are available |
| `Ensure-DefenderRealtime` | Verifies Defender real-time protection and signature freshness |
| `Ensure-FastbootDisabled` | Disables Windows Fast Startup |
| `Ensure-FirewallEnabled` | Ensures Windows Firewall profiles are enabled |
| `Ensure-LDAPClientEncryption` | Enforces LDAP client signing/encryption-related settings |
| `Ensure-NetBIOSDisabled` | Disables NetBIOS where configured |
| `Ensure-SMBSigning` | Enforces SMB signing |
| `Ensure-SMBv1Disabled` | Disables SMBv1 |
| `Ensure-UACDenyElevation` | Applies the configured UAC elevation behavior |
| `Nudge-RebootUptime` | Prompts users to reboot after excessive uptime |
| `Reset-LocalAdmins` | Removes local Administrators group members not on the allowlist |

## Recommended Intune settings

Unless a remediation README explicitly says otherwise:

- Run using the logged-on credentials: **No**
- Enforce script signature check: according to your code-signing policy
- Run script in 64-bit PowerShell: **Yes**

Start with a small pilot group before broad assignment. Security remediations can conflict with legacy applications, third-party security products or environment-specific requirements.

## Code signing

The `_codesign` directory contains helper tooling for a private signing setup. Do not commit private keys, exported signing certificates or other signing secrets to this repository.
