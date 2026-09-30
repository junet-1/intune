# Remediation: Ensure Firewall Enabled

Intune-Remediation-Paket, das die Windows Defender Firewall für alle drei Profile
(Domäne, Privat, Öffentlich) eingeschaltet hält. Regeln werden nicht verändert –
nur der Ein/Aus-Schalter pro Profil.

## Dateien

| Datei | Rolle in Intune |
|-------|-----------------|
| Detect-FirewallEnabled.ps1 | Detection script (Exit 1 = mindestens ein Profil aus) |
| Remediate-FirewallEnabled.ps1 | Remediation script (schaltet alle Profile ein) |

## Deployment in Intune

1. Endpoint Manager → Devices → Remediations → Create.
2. Detection: Detect-FirewallEnabled.ps1, Remediation: Remediate-FirewallEnabled.ps1.
3. Run this script using the logged-on credentials: No (SYSTEM).
4. Run script in 64-bit PowerShell: Yes.
5. Zeitplan zuweisen (z. B. täglich).

## Signieren

```bash
./_codesign/sign-scripts.sh <cert-dir> \
  Ensure-FirewallEnabled/Detect-FirewallEnabled.ps1 \
  Ensure-FirewallEnabled/Remediate-FirewallEnabled.ps1
```
