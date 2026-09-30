# Remediation: Ensure SMB Signing

Intune-Remediation-Paket, das erzwungenes SMB-Signing für Client und Server
sicherstellt. Schützt gegen SMB-Relay und Manipulation.

## Dateien

| Datei | Rolle in Intune |
|-------|-----------------|
| Detect-SMBSigning.ps1 | Detection script (Exit 1 = Signing nicht erzwungen) |
| Remediate-SMBSigning.ps1 | Remediation script (setzt RequireSecuritySignature=1) |

## Was gesetzt wird

RequireSecuritySignature = 1 unter

- LanmanWorkstation\Parameters (Client)
- LanmanServer\Parameters (Server)

## Deployment in Intune

1. Endpoint Manager → Devices → Scripts and remediations → Create.
2. Detection: Detect-SMBSigning.ps1, Remediation: Remediate-SMBSigning.ps1.
3. Run this script using the logged-on credentials: No (SYSTEM).
4. Run script in 64-bit PowerShell: Yes.

## Signieren

```bash
./_codesign/sign-scripts.sh <cert-dir> \
  Ensure-SMBSigning/Detect-SMBSigning.ps1 \
  Ensure-SMBSigning/Remediate-SMBSigning.ps1
```

## Herkunft

Idee adaptiert aus EndpointAnalyticsRemediationScripts (MIT). Das Original
verwendete ungültige Registry-Pfade (HKLM ohne Provider-Doppelpunkt); hier
korrigiert und auf Client plus Server erweitert.
