# Remediation: Ensure UAC Deny Elevation

Intune remediation package that keeps the UAC prompt for standard users at
"Automatically deny elevation requests". When an action requires elevated
rights, the user no longer gets a credential prompt but an access denied message.

The script manages ConsentPromptBehaviorUser under
`HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System`:

| Value | Meaning |
|-------|---------|
| 0 | Automatically deny elevation requests (target value) |
| 1 | Prompt for credentials on the secure desktop |
| 3 | Prompt for credentials (default) |

Equivalent to Computer Configuration > Windows Settings > Security Settings >
Local Policies > Security Options > "User Account Control: Behavior of the
elevation prompt for standard users" and CIS 2.3.17.3.

## Files

| File | Role in Intune |
|------|----------------|
| Detect-UACDenyElevation.ps1 | Detection script (exit 1 = ConsentPromptBehaviorUser not 0) |
| Remediate-UACDenyElevation.ps1 | Remediation script (ConsentPromptBehaviorUser=0) |

## Deployment in Intune

1. Intune admin center → Devices → Scripts and remediations → Create.
2. Detection: Detect-UACDenyElevation.ps1, Remediation: Remediate-UACDenyElevation.ps1.
3. Run this script using the logged-on credentials: No (SYSTEM).
4. Run script in 64-bit PowerShell: Yes.

## Effect

The change applies without a reboot; processes that are already running keep
their token. Applications that trigger an installation or an action with admin
rights now fail for standard users without a prompt. Before a broad rollout,
check whether support procedures rely on entering an admin password on the
client – that's no longer possible; elevation then needs an admin sign-in or a
tool such as Endpoint Privilege Management.

The setting only works while UAC is on (EnableLUA=1). If EnableLUA is 0,
ConsentPromptBehaviorUser has no effect, but the detection still reports
compliant.

Alternatively, the same value can be set through the Settings Catalog (Local
Policies Security Options > User Account Control Behavior Of The Elevation Prompt
For Standard Users). If both are assigned, the remediation writes to the same key
the Policy CSP manages – use only one of the two.

## Signing

```bash
./_codesign/sign-scripts.sh <cert-dir> \
  Ensure-UACDenyElevation/Detect-UACDenyElevation.ps1 \
  Ensure-UACDenyElevation/Remediate-UACDenyElevation.ps1
```
