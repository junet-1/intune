# Remediation: Ensure UAC Deny Elevation

Intune-Remediation-Paket, das die UAC-Eingabeaufforderung fuer Standardbenutzer
auf "Automatically deny elevation requests" haelt. Erfordert eine Aktion erhoehte
Rechte, bekommt der Benutzer keine Anmeldemaske mehr, sondern eine
Zugriff-verweigert-Meldung.

Gesteuert wird ConsentPromptBehaviorUser unter
HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System:

| Wert | Bedeutung |
|------|-----------|
| 0 | Elevation-Anfragen automatisch ablehnen (Zielwert) |
| 1 | Nach Anmeldeinformationen auf dem sicheren Desktop fragen |
| 3 | Nach Anmeldeinformationen fragen (Standard) |

Entspricht Computer Configuration > Windows Settings > Security Settings >
Local Policies > Security Options > "User Account Control: Behavior of the
elevation prompt for standard users" und CIS 2.3.17.3.

## Dateien

| Datei | Rolle in Intune |
|-------|-----------------|
| Detect-UACDenyElevation.ps1 | Detection script (Exit 1 = ConsentPromptBehaviorUser nicht 0) |
| Remediate-UACDenyElevation.ps1 | Remediation script (ConsentPromptBehaviorUser=0) |

## Deployment in Intune

1. Endpoint Manager → Devices → Scripts and remediations → Create.
2. Detection: Detect-UACDenyElevation.ps1, Remediation: Remediate-UACDenyElevation.ps1.
3. Run this script using the logged-on credentials: No (SYSTEM).
4. Run script in 64-bit PowerShell: Yes.

## Wirkung

Die Aenderung greift ohne Neustart, bereits laufende Prozesse behalten ihr Token.
Anwendungen, die eine Installation oder eine Aktion mit Adminrechten anstossen,
schlagen fuer Standardbenutzer ab sofort ohne Rueckfrage fehl. Vor dem breiten
Ausrollen pruefen, ob Support-Ablaeufe darauf beruhen, dass am Client ein
Adminkennwort eingegeben wird - das ist damit nicht mehr moeglich, Erhoehung
braucht dann eine Admin-Anmeldung oder ein Tool wie Endpoint Privilege Management.

Die Einstellung wirkt nur, solange UAC aktiv ist (EnableLUA=1). Ist EnableLUA auf 0
gesetzt, ist ConsentPromptBehaviorUser wirkungslos, die Detection meldet aber
weiterhin konform.

Alternativ laesst sich derselbe Wert ueber den Settings Catalog setzen
(Local Policies Security Options > User Account Control Behavior Of The Elevation
Prompt For Standard Users). Wird beides gleichzeitig zugewiesen, schreibt die
Remediation in denselben Schluessel, den der Policy-CSP verwaltet - dann nur einen
der beiden Wege nutzen.

## Signieren

```bash
./_codesign/sign-scripts.sh <cert-dir> \
  Ensure-UACDenyElevation/Detect-UACDenyElevation.ps1 \
  Ensure-UACDenyElevation/Remediate-UACDenyElevation.ps1
```
