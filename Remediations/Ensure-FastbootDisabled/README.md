# Remediation: Ensure Fast Startup Disabled

Intune-Remediation-Paket, das Windows Fast Startup (Hybrid-Boot) deaktiviert
hält. Fast Startup verhindert oft, dass Updates, Treiber oder Richtlinien bis
zum echten Neustart greifen.

## Dateien

| Datei | Rolle in Intune |
|-------|-----------------|
| Detect-FastbootDisabled.ps1 | Detection script (Exit 1 = Fast Startup aktiv) |
| Remediate-FastbootDisabled.ps1 | Remediation script (HiberbootEnabled=0) |

## Deployment in Intune

1. Endpoint Manager → Devices → Scripts and remediations → Create.
2. Detection: Detect-FastbootDisabled.ps1, Remediation: Remediate-FastbootDisabled.ps1.
3. Run this script using the logged-on credentials: No (SYSTEM).
4. Run script in 64-bit PowerShell: Yes.

## Signieren

```bash
./_codesign/sign-scripts.sh <cert-dir> \
  Ensure-FastbootDisabled/Detect-FastbootDisabled.ps1 \
  Ensure-FastbootDisabled/Remediate-FastbootDisabled.ps1
```

## Herkunft

Idee adaptiert aus EndpointAnalyticsRemediationScripts (Jannik Reinhard u. a.),
MIT-Lizenz.
