# Remediation: Ensure Core Services

Intune-Remediation-Paket, das wichtige Dienste überwacht und startet bzw.
reaktiviert, wenn sie deaktiviert oder gestoppt sind. Standardmäßig:

- ClickToRunSvc (Office Click-to-Run)
- wuauserv (Windows Update)

## Dateien

| Datei | Rolle in Intune |
|-------|-----------------|
| Detect-CoreServices.ps1 | Detection script (Exit 1 = Dienst deaktiviert oder gestoppt) |
| Remediate-CoreServices.ps1 | Remediation script (setzt Starttyp, startet Dienst) |

## Konfiguration

Die Dienstliste steht im Config-Block am Anfang beider Skripte, identisch halten.
Pro Dienst: Name, DesiredStartType, EnsureRunning. Nicht installierte Dienste
werden übersprungen (z. B. ClickToRunSvc auf Geräten ohne Click-to-Run-Office).

## Hinweis zu wuauserv

wuauserv ist trigger-started und liegt im Normalbetrieb absichtlich im Zustand
Gestoppt. Mit EnsureRunning = true meldet die Detection den Dienst daher in den
meisten Zyklen als non-compliant und startet ihn jedes Mal neu. Das ist harmlos,
erzeugt aber Rauschen im Reporting. Wer nur gegen ein versehentliches oder
manipuliertes Disabled schützen will, setzt EnsureRunning für wuauserv auf false.

## Deployment in Intune

1. Endpoint Manager → Devices → Scripts and remediations → Create.
2. Detection: Detect-CoreServices.ps1, Remediation: Remediate-CoreServices.ps1.
3. Run this script using the logged-on credentials: No (SYSTEM).
4. Run script in 64-bit PowerShell: Yes.

## Signieren

```bash
./_codesign/sign-scripts.sh <cert-dir> \
  Ensure-CoreServices/Detect-CoreServices.ps1 \
  Ensure-CoreServices/Remediate-CoreServices.ps1
```
