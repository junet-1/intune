# Remediation: Ensure SMBv1 Disabled

Intune-Remediation-Paket, das den veralteten SMBv1-Server deaktiviert hält.
SMBv1 ist ein bekannter Ransomware-/Wurm-Vektor (WannaCry, NotPetya).

## Dateien

| Datei | Rolle in Intune |
|-------|-----------------|
| Detect-SMBv1Disabled.ps1 | Detection script (Exit 1 = SMBv1 aktiv) |
| Remediate-SMBv1Disabled.ps1 | Remediation script (deaktiviert SMBv1) |

## Deployment in Intune

1. Endpoint Manager → Devices → Scripts and remediations → Create.
2. Detection: Detect-SMBv1Disabled.ps1, Remediation: Remediate-SMBv1Disabled.ps1.
3. Run this script using the logged-on credentials: No (SYSTEM).
4. Run script in 64-bit PowerShell: Yes.

## Signieren

```bash
./_codesign/sign-scripts.sh <cert-dir> \
  Ensure-SMBv1Disabled/Detect-SMBv1Disabled.ps1 \
  Ensure-SMBv1Disabled/Remediate-SMBv1Disabled.ps1
```

## Herkunft

Idee adaptiert aus EndpointAnalyticsRemediationScripts (Jannik Reinhard u. a.),
MIT-Lizenz. Neu geschrieben im Muster dieser Sammlung mit -Force und Verifikation.
