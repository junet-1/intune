# Remediation: Ensure Firewall Enabled

Intune remediation package that keeps Windows Defender Firewall turned on for all
three profiles (domain, private, public). Rules are not changed – only the on/off
switch per profile.

## Files

| File | Role in Intune |
|------|----------------|
| Detect-FirewallEnabled.ps1 | Detection script (exit 1 = at least one profile off) |
| Remediate-FirewallEnabled.ps1 | Remediation script (turns all profiles on) |

## Deployment in Intune

1. Intune admin center → Devices → Scripts and remediations → Create.
2. Detection: Detect-FirewallEnabled.ps1, Remediation: Remediate-FirewallEnabled.ps1.
3. Run this script using the logged-on credentials: No (SYSTEM).
4. Run script in 64-bit PowerShell: Yes.
5. Assign a schedule (e.g. daily).

## Signing

```bash
./_codesign/sign-scripts.sh <cert-dir> \
  Ensure-FirewallEnabled/Detect-FirewallEnabled.ps1 \
  Ensure-FirewallEnabled/Remediate-FirewallEnabled.ps1
```
