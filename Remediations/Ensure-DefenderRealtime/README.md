# Remediation: Ensure Defender Realtime

Intune remediation package that keeps Microsoft Defender real-time protection on
and signatures current. If Defender runs in passive or EDR block mode (a
third-party AV is active), the device counts as compliant and nothing is changed.

## Files

| File | Role in Intune |
|------|----------------|
| Detect-DefenderRealtime.ps1 | Detection script (exit 1 = real-time protection off or signatures too old) |
| Remediate-DefenderRealtime.ps1 | Remediation script (turns on real-time protection, updates signatures) |

## Configuration

At the top of both scripts; keep them identical:

- MaxSignatureAgeDays: maximum signature age in days (default 7).

## Deployment in Intune

1. Intune admin center → Devices → Scripts and remediations → Create.
2. Detection: Detect-DefenderRealtime.ps1, Remediation: Remediate-DefenderRealtime.ps1.
3. Run this script using the logged-on credentials: No (SYSTEM).
4. Run script in 64-bit PowerShell: Yes.
5. Assign a schedule (e.g. daily).

## Signing

```bash
./_codesign/sign-scripts.sh <cert-dir> \
  Ensure-DefenderRealtime/Detect-DefenderRealtime.ps1 \
  Ensure-DefenderRealtime/Remediate-DefenderRealtime.ps1
```
