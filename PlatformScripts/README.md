# Windows Platform Scripts

Eigenständige Intune Platform Scripts (Devices → Scripts and remediations →
Platform scripts). Jedes Skript ist in sich geschlossen, idempotent und läuft als
SYSTEM. Protokolliert wird nach C:\\ProgramData\\IntuneScripts\\Logs. Exit 0 = Erfolg,
nicht-null = Fehler (Intune wiederholt).

## Skripte

| Skript                               | Intune-Name                      | Kategorie       | Zweck                                                                                                                       |
|--------------------------------------|----------------------------------|-----------------|-----------------------------------------------------------------------------------------------------------------------------|
| PS-D-WIN-AutoAcceptSSO.ps1           | PS-D-WIN-AutoAcceptSSO           | UX/Config       | Prüft und setzt `AutoAcceptSsoPermission=1` als maschinenweite Windows-AAD-Richtlinie                                      |
| PS-D-WIN-TimeZoneAuto.ps1            | PS-D-WIN-TimeZoneAuto            | UX/Config       | Zeitzone automatisch (Standortdienst + tzautoupdate)                                                                        |
| PS-D-WIN-PowerConfig.ps1             | PS-D-WIN-PowerConfig             | UX/Config       | Kein Sleep am Netzteil, Display-Timeout konfigurierbar                                                                      |
| PS-D-WIN-ExplorerDefaults.ps1        | PS-D-WIN-ExplorerDefaults        | UX/Config       | Dateiendungen anzeigen, Explorer öffnet "Dieser PC" – für alle und künftige Nutzer                                          |
| PS-D-WIN-DisableConsumerFeatures.ps1 | PS-D-WIN-DisableConsumerFeatures | Debloat         | Deaktiviert Consumer-/Werbe-Inhalte, Spotlight-Tipps, Widgets                                                               |
| PS-D-WIN-RemoveConsumerBloat.ps1     | PS-D-WIN-RemoveConsumerBloat     | Debloat         | Entfernt Consumer-Apps provisioned und für alle Nutzer, gegen eine Schutzliste abgesichert                                  |
| PS-D-WIN-DefaultAppAssociations.ps1  | PS-D-WIN-DefaultAppAssociations  | UX/Config       | Importiert die Standard-Dateizuordnungen per DISM (PDF → Adobe Acrobat Reader DC, Skriptformate → Notepad++)                |
| PS-D-WIN-ScriptFileSafety.ps1        | PS-D-WIN-ScriptFileSafety        | Härtung         | Setzt für ausführbare Textformate Notepad++ als Standardverb und deaktiviert den Windows Script Host                        |
| PS-D-WIN-BiosBaseline.ps1            | PS-D-WIN-BiosBaseline            | Härtung         | Schaltet die Firmware-Sicherheitsfunktionen der Baseline über die BIOS-Schnittstelle des Herstellers ein (Dell, HP, Lenovo) |
| PS-D-WIN-SystemTweaks.ps1            | PS-D-WIN-SystemTweaks            | UX/Config       | Kleine maschinenweite Oberflächen-Anpassungen                                                                               |
| PS-D-WIN-OemBranding.ps1             | PS-D-WIN-OemBranding             | UX/Config       | Hersteller, Support-Infos, Logo und registrierten Besitzer unter System > Info setzen                                       |
| PS-D-WIN-DesktopLockScreen.ps1       | PS-D-WIN-DesktopLockScreen       | UX/Config       | Desktop-Hintergrund und Sperrbildschirm per PersonalizationCSP setzen                                                       |
| PS-D-WIN-CreateShortcut.ps1          | PS-D-WIN-CreateShortcut          | Deployment      | Legt eine All-User-Verknüpfung an (Desktop/Startmenü)                                                                       |
| PS-D-WIN-InstallFonts.ps1            | PS-D-WIN-InstallFonts            | Deployment      | Installiert Schriftarten maschinenweit                                                                                      |
| PS-D-WIN-WindowsFeatures.ps1         | PS-D-WIN-WindowsFeatures         | UX/Config       | Windows-Features hinzufügen, deaktivieren und entfernen                                                                     |

Der Intune-Name steht im Abschnitt .NAME des jeweiligen Skripts. Schema: PS für
Platform Script, REM für Remediation, D oder U für Geräte- bzw. Benutzerkontext,
dann Plattform und Zweck.

## Standard-Deployment

1. Endpoint Manager → Devices → Scripts and remediations → Platform scripts → Add → Windows 10 and later.
2. Skriptdatei hochladen.
3. Run this script using the logged-on credentials: No (SYSTEM).
4. Enforce script signature check: nach Bedarf.
5. Run script in 64-bit PowerShell Host: Yes.
6. Zuweisen.

## Hinweise pro Skript

- PS-D-WIN-ExplorerDefaults: greift für angemeldete Nutzer erst nach Ab-/Anmelden bzw. Explorer-Neustart. Neue Nutzer erben die Werte über das Default-Profil.
- PS-D-WIN-RemoveConsumerBloat: Target- und Protected-Liste im Konfigblock vor dem Rollout prüfen. Namen unterstützen Wildcards, die Schutzliste gewinnt gegen ein zu weit gefasstes Muster. Werden Apps zusätzlich per Settings Catalog oder Autopilot-Branding entfernt, die Listen abgleichen, sonst arbeiten Policy und Skript gegeneinander.
- PS-D-WIN-CreateShortcut: Parameter-Defaults anpassen oder mehrere Kopien mit unterschiedlichen Werten verteilen. Platform Scripts nehmen selbst keine Parameter entgegen – Werte also im Skript setzen.
- PS-D-WIN-DefaultAppAssociations: DISM schreibt die Zuordnungen in das Standardprofil. Sie greifen damit für Profile, die danach angelegt werden. Adobe Acrobat Reader DC und Notepad++ müssen vor der ersten Anmeldung installiert sein, sonst fällt Windows auf die eigenen Standards zurück. Beide daher als Required App zuweisen und im ESP als blockierende App führen.
- PS-D-WIN-ScriptFileSafety: optional. Nötig nur dort, wo der DISM-Import nicht hinreicht, also bei bereits angelegten Profilen und bei bat/cmd, die Windows nicht zuverlässig über die Standardzuordnungen führt. Schreibt maschinenweit unter HKLM\\SOFTWARE\\Classes und wirkt sofort für alle Nutzer. Der bisherige Standardverb wird unter HKLM\\SOFTWARE\\IntuneScripts\\FileTypeSafety abgelegt, damit die Änderung zurückgenommen werden kann. Läuft erst, wenn Notepad++ installiert ist, sonst Exit 1 und Intune wiederholt. Der Schalter $DisableWindowsScriptHost steht auf $false – er geht über den Fehlklick-Schutz hinaus und bricht vbs/js-Aufrufe.
- Reichweite der Zuordnungen: sie ändern nur, was das Standardverb auslöst, also Doppelklick und ShellExecute. cmd /c, wscript, powershell -File und der Rechtsklick-Eintrag "Ausführen" bleiben unberührt. Startet eine Anwendung eine bat-Datei über ShellExecute statt über CreateProcess, öffnet sie ab jetzt Notepad++ – bei Fachanwendungen vor dem Rollout gegenprüfen. Die Ausführung selbst sollten Attack-Surface-Reduction-Regeln und die Ausführungsrichtlinie AllSigned begrenzen. Eine per "Öffnen mit → Immer" getroffene Nutzerwahl gewinnt für diesen Nutzer und diese Endung weiterhin.
- PS-D-WIN-BiosBaseline: schreibt je nach Hersteller über root\\dcim\\sysman\\biosattributes (Dell, agentfreies WMI-ACPI) bzw. root\\dell\\sysman (Dell Command | Monitor als Rückfallweg), root\\hp\\instrumentedBIOS (HP) oder root\\wmi mit Lenovo_SetBiosSetting und anschließendem Lenovo_SaveBiosSettings. Die Attributnamen unterscheiden sich je Hersteller und Modell, deshalb steht keiner fest im Skript: es liest die vorhandenen Attribute aus, nimmt den ersten Treffer aus der Kandidatenliste des Herstellers und fällt sonst auf einen Namensabgleich per Muster zurück. Den zu schreibenden Wert holt es aus der Werteliste des Attributs selbst, damit Enabled, Enable, Active und Available gleichermaßen passen.
- PS-D-WIN-BiosBaseline, Umfang: die Tabelle $Features im Konfigblock steuert alles. Enthalten sind VT-d, VT-x, TPM sichtbar und aktiv, DMA-Schutz, SMM-Mitigation, Speicherverschlüsselung und Intel TXT – ausschließlich Funktionen ohne Betriebsrisiko. Je Zeile liest das Skript den Ist-Zustand, lässt eine bereits eingeschaltete Funktion in Ruhe und schaltet eine ausgeschaltete ein. Nichts davon verändert das Bootverhalten, und ein TPM wird nie gelöscht: Namen mit clear, reset, erase und Ähnlichem sind vom Abgleich generell ausgenommen, damit ein weit gefasstes Muster nicht auf einem Lösch-Schalter landet. Nicht vorhandene Funktionen werden protokolliert und übersprungen, ebenso schreibgeschützte Attribute und Werte, die weder als an noch als aus lesbar sind.
- PS-D-WIN-BiosBaseline, Betrieb: ist ein BIOS-Kennwort gesetzt, gehört es in $BiosPassword, sonst weist die Firmware jeden Schreibvorgang ab. Auf dem Dell-Nativpfad prüft das Skript das vorab über PasswordObject in root\\dcim\\sysman\\wmisecurity und bricht mit einer klaren Meldung ab, statt in einen nichtssagenden Statuscode zu laufen. Vor dem ersten Schreibvorgang wird BitLocker auf dem Systemlaufwerk für einen Neustart ausgesetzt, weil die geänderten PCR-Messwerte das Gerät sonst in die Wiederherstellung schicken. Die Einstellungen greifen mit dem nächsten Neustart, der separat einzuplanen ist. Exit 1 bei fehlendem Provider, abgewiesenem Schreibvorgang oder fehlendem TXT – TXT ist als einzige Zeile als erforderlich markiert, weil manche Firmwares es erst nach eingeschaltetem VT-x und VT-d anzeigen. Der erste Lauf schaltet dann die Voraussetzungen ein, der Intune-Wiederholungslauf nach dem Neustart findet TXT und schließt ab.
- PS-D-WIN-BiosBaseline, Wirkung von TXT: TXT ist die Voraussetzung für System Guard Secure Launch (DRTM). Ohne die passende VBS-Einstellung in Intune bleibt die Funktion ungenutzt.
- PS-D-WIN-InstallFonts: Schriftdateien in einen Unterordner "Fonts" neben das Skript packen. Platform Scripts laden nur eine einzelne .ps1 hoch; für Begleitdateien stattdessen als Win32-App (.intunewin) verpacken.

## Signieren

Vor der Verteilung signieren (für AllSigned zwingend):

```bash
./../Remediations/_codesign/sign-scripts.sh <cert-dir> \
  PS-D-WIN-AutoAcceptSSO.ps1 PS-D-WIN-TimeZoneAuto.ps1 PS-D-WIN-PowerConfig.ps1 PS-D-WIN-ExplorerDefaults.ps1 \
  PS-D-WIN-DisableConsumerFeatures.ps1 PS-D-WIN-CreateShortcut.ps1 PS-D-WIN-InstallFonts.ps1 \
  PS-D-WIN-DefaultAppAssociations.ps1 PS-D-WIN-ScriptFileSafety.ps1 PS-D-WIN-BiosBaseline.ps1
```
