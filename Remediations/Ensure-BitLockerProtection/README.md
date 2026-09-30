# Remediation: Ensure BitLocker Protection

Intune remediation package that keeps BitLocker protection of the operating
system drive turned on. Suspended protection is resumed.

## Scope

The remediation resumes suspended protection with Resume-BitLocker. A fully
decrypted drive is not encrypted automatically – that requires TPM state and
recovery key escrow and belongs in a dedicated encryption profile. In that case
the remediation returns exit 1 and the device visibly stays non-compliant.

## Files

| File | Role in Intune |
|------|----------------|
| Detect-BitLockerProtection.ps1 | Detection script (exit 1 = ProtectionStatus not On) |
| Remediate-BitLockerProtection.ps1 | Remediation script (resumes suspended protection) |

## Deployment in Intune

1. Intune admin center → Devices → Scripts and remediations → Create.
2. Detection: Detect-BitLockerProtection.ps1, Remediation: Remediate-BitLockerProtection.ps1.
3. Run this script using the logged-on credentials: No (SYSTEM).
4. Run script in 64-bit PowerShell: Yes.
5. Assign a schedule (e.g. daily).

## Signing

```bash
./_codesign/sign-scripts.sh <cert-dir> \
  Ensure-BitLockerProtection/Detect-BitLockerProtection.ps1 \
  Ensure-BitLockerProtection/Remediate-BitLockerProtection.ps1
```
