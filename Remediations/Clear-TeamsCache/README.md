# Remediation: Clear Teams Cache

Intune-Remediation-Paket, das einen aufgeblähten Teams-Cache des angemeldeten
Nutzers bereinigt. Behebt typische Teams-Probleme (langsam, hängt beim Anmelden,
zeigt Veraltetes).

## Kontext

Läuft im Benutzerkontext (runAsAccount = user), weil der Cache im Userprofil
liegt. Läuft Teams gerade, überspringt die Remediation die Bereinigung, um keine
aktive Sitzung zu stören; der nächste Zyklus räumt auf, sobald Teams zu ist.

## Dateien

| Datei | Rolle in Intune |
|-------|-----------------|
| Detect-TeamsCache.ps1 | Detection script (Exit 1 = Cache größer als Schwelle) |
| Remediate-TeamsCache.ps1 | Remediation script (leert Cache, wenn Teams zu ist) |

## Konfiguration

MaxCacheMB (Standard 500) am Anfang beider Skripte, identisch halten.

## Deployment in Intune

1. Endpoint Manager → Devices → Scripts and remediations → Create.
2. Detection: Detect-TeamsCache.ps1, Remediation: Remediate-TeamsCache.ps1.
3. Run this script using the logged-on credentials: Yes (Benutzerkontext).
4. Run script in 64-bit PowerShell: Yes.

## Signieren

```bash
./_codesign/sign-scripts.sh <cert-dir> \
  Clear-TeamsCache/Detect-TeamsCache.ps1 \
  Clear-TeamsCache/Remediate-TeamsCache.ps1
```

## Herkunft

Idee adaptiert aus EndpointAnalyticsRemediationScripts (MIT). Neu geschrieben mit
Schwellwert-Erkennung, Schutz gegen laufendes Teams und Unterstützung für classic
und new Teams.
