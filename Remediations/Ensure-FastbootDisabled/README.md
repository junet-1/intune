# Remediation: Ensure Fast Startup Disabled

Intune remediation package that keeps Windows Fast Startup (hybrid boot) turned
off. Fast Startup often prevents updates, drivers or policies from taking effect
until a real restart.

## Files

| File | Role in Intune |
|------|----------------|
| Detect-FastbootDisabled.ps1 | Detection script (exit 1 = Fast Startup on) |
| Remediate-FastbootDisabled.ps1 | Remediation script (HiberbootEnabled=0) |

## Deployment in Intune

1. Intune admin center → Devices → Scripts and remediations → Create.
2. Detection: Detect-FastbootDisabled.ps1, Remediation: Remediate-FastbootDisabled.ps1.
3. Run this script using the logged-on credentials: No (SYSTEM).
4. Run script in 64-bit PowerShell: Yes.

## Signing

```bash
./_codesign/sign-scripts.sh <cert-dir> \
  Ensure-FastbootDisabled/Detect-FastbootDisabled.ps1 \
  Ensure-FastbootDisabled/Remediate-FastbootDisabled.ps1
```

## Origin

Idea adapted from EndpointAnalyticsRemediationScripts (Jannik Reinhard et al.,
MIT), see THIRD-PARTY-NOTICES.md.
