# Remediation: Ensure SMBv1 Disabled

Intune remediation package that keeps the legacy SMBv1 server turned off. SMBv1
is a well-known ransomware and worm vector (WannaCry, NotPetya).

## Files

| File | Role in Intune |
|------|----------------|
| Detect-SMBv1Disabled.ps1 | Detection script (exit 1 = SMBv1 on) |
| Remediate-SMBv1Disabled.ps1 | Remediation script (turns SMBv1 off) |

## Deployment in Intune

1. Intune admin center → Devices → Scripts and remediations → Create.
2. Detection: Detect-SMBv1Disabled.ps1, Remediation: Remediate-SMBv1Disabled.ps1.
3. Run this script using the logged-on credentials: No (SYSTEM).
4. Run script in 64-bit PowerShell: Yes.

## Signing

```bash
./_codesign/sign-scripts.sh <cert-dir> \
  Ensure-SMBv1Disabled/Detect-SMBv1Disabled.ps1 \
  Ensure-SMBv1Disabled/Remediate-SMBv1Disabled.ps1
```

## Origin

Idea adapted from EndpointAnalyticsRemediationScripts (Jannik Reinhard et al.,
MIT), see THIRD-PARTY-NOTICES.md. Rewritten in the style of this collection with
-Force and verification.
