# Remediation: Ensure Defender Realtime

Intune-Remediation-Paket, das den Echtzeitschutz von Microsoft Defender aktiv und
die Signaturen aktuell hält. Läuft Defender im passiven bzw. EDR-Block-Modus
(ein Drittanbieter-AV ist aktiv), gilt das Gerät als konform und es wird nichts
verändert.

## Dateien

| Datei | Rolle in Intune |
|-------|-----------------|
| Detect-DefenderRealtime.ps1 | Detection script (Exit 1 = Echtzeitschutz aus oder Signaturen zu alt) |
| Remediate-DefenderRealtime.ps1 | Remediation script (aktiviert Echtzeitschutz, aktualisiert Signaturen) |

## Konfiguration

Am Anfang beider Skripte, identisch halten:

- MaxSignatureAgeDays: maximales Signaturalter in Tagen (Standard 7).

## Deployment in Intune

1. Endpoint Manager → Devices → Remediations → Create.
2. Detection: Detect-DefenderRealtime.ps1, Remediation: Remediate-DefenderRealtime.ps1.
3. Run this script using the logged-on credentials: No (SYSTEM).
4. Run script in 64-bit PowerShell: Yes.
5. Zeitplan zuweisen (z. B. täglich).

## Signieren

```bash
./_codesign/sign-scripts.sh <cert-dir> \
  Ensure-DefenderRealtime/Detect-DefenderRealtime.ps1 \
  Ensure-DefenderRealtime/Remediate-DefenderRealtime.ps1
```
