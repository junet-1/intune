# Remediation: Ensure LDAP Client Encryption

Intune remediation package that requires encryption (sealing or TLS) for LDAP
connections made by the Windows client. Protects directory data and credentials
in transit. Complements LDAP client signing; it doesn't replace it.

## Files

| File | Role in Intune |
|------|----------------|
| Detect-LDAPClientEncryption.ps1 | Detection script (exit 1 = encryption not required) |
| Remediate-LDAPClientEncryption.ps1 | Remediation script (sets LDAPClientConfidentiality=2) |

## What is set

LDAPClientConfidentiality = 2 (DWORD) under
`HKLM\SYSTEM\CurrentControlSet\Services\ldap`

| Value | Meaning |
|-------|---------|
| 0 | None |
| 1 | Negotiate (default) |
| 2 | Require |

Takes effect with the next LDAP connection, no reboot needed. Evaluated from
Windows 11 24H2; older builds ignore the value.

With Require, LDAP connections to servers that offer neither sealing nor TLS
fail (e.g. simple LDAP binds against third-party systems on port 389).

## Deployment in Intune

1. Intune admin center → Devices → Scripts and remediations → Create.
2. Detection: Detect-LDAPClientEncryption.ps1, Remediation: Remediate-LDAPClientEncryption.ps1.
3. Run this script using the logged-on credentials: No (SYSTEM).
4. Run script in 64-bit PowerShell: Yes.

## Signing

```bash
./_codesign/sign-scripts.sh <cert-dir> \
  Ensure-LDAPClientEncryption/Detect-LDAPClientEncryption.ps1 \
  Ensure-LDAPClientEncryption/Remediate-LDAPClientEncryption.ps1
```

## Origin

Adapted from pariswells.com, "Encrypt LDAP client traffic to protect sensitive
data in transit (Intune)", aligned with the logging and naming of the other
remediations in this collection.
