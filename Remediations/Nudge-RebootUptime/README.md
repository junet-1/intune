# Remediation: Reboot Reminder (Uptime)

Intune-Remediation-Paket, das Nutzer an einen Neustart erinnert, wenn ein Gerät
zu lange ohne Neustart läuft. Es wird bewusst nicht neu gestartet, nur erinnert.

## Kontext

Läuft im Benutzerkontext (runAsAccount = user), damit die Erinnerung als Toast
beim angemeldeten Nutzer erscheint. Fällt der Toast aus, greift eine Meldung über
msg.exe (auf Pro/Enterprise vorhanden).

## Dateien

| Datei | Rolle in Intune |
|-------|-----------------|
| Detect-UptimeReboot.ps1 | Detection script (Exit 1 = Uptime über Schwelle) |
| Remediate-UptimeReboot.ps1 | Remediation script (zeigt Erinnerung, kein Reboot) |

## Konfiguration

MaxUptimeDays (Standard 7) am Anfang beider Skripte, identisch halten.

## Deployment in Intune

1. Endpoint Manager → Devices → Scripts and remediations → Create.
2. Detection: Detect-UptimeReboot.ps1, Remediation: Remediate-UptimeReboot.ps1.
3. Run this script using the logged-on credentials: Yes (Benutzerkontext).
4. Run script in 64-bit PowerShell: Yes.

## Hinweis

Bewusst ohne Zwangs-Reboot – Geräte sollen nie ohne Zutun des Benutzers neu starten.
Der Toast nutzt WinRT und läuft unter Windows PowerShell 5.1, was Intune
standardmäßig verwendet.
