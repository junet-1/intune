# Remediation: Ensure BitLocker Protection

Intune-Remediation-Paket, das den BitLocker-Schutz des Betriebssystemlaufwerks
eingeschaltet hält. Ein ausgesetzter (suspended) Schutz wird fortgesetzt.

## Umfang

Die Remediation setzt einen ausgesetzten Schutz mit Resume-BitLocker fort. Ein
vollständig entschlüsseltes Laufwerk wird nicht automatisch verschlüsselt – das
erfordert TPM-Zustand und Wiederherstellungsschlüssel-Escrow und gehört in ein
eigenes Verschlüsselungsprofil. In diesem Fall meldet die Remediation Exit 1 und
das Gerät bleibt sichtbar nicht konform.

## Dateien

| Datei | Rolle in Intune |
|-------|-----------------|
| Detect-BitLockerProtection.ps1 | Detection script (Exit 1 = ProtectionStatus nicht On) |
| Remediate-BitLockerProtection.ps1 | Remediation script (Resume bei ausgesetztem Schutz) |

## Deployment in Intune

1. Endpoint Manager → Devices → Remediations → Create.
2. Detection: Detect-BitLockerProtection.ps1, Remediation: Remediate-BitLockerProtection.ps1.
3. Run this script using the logged-on credentials: No (SYSTEM).
4. Run script in 64-bit PowerShell: Yes.
5. Zeitplan zuweisen (z. B. täglich).

## Signieren

```bash
./_codesign/sign-scripts.sh <cert-dir> \
  Ensure-BitLockerProtection/Detect-BitLockerProtection.ps1 \
  Ensure-BitLockerProtection/Remediate-BitLockerProtection.ps1
```
