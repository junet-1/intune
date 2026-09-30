# Remediation: Reset Local Admins (außer LAPS-Admin)

Intune-Remediation-Paket, das die lokale Gruppe **Administratoren** auf eine
Allowlist erzwingt. Alle nicht erlaubten Konten werden entfernt, der
LAPS-verwaltete Admin **LAPS-Admin** bleibt erhalten.

## Dateien

| Datei | Rolle in Intune |
|-------|-----------------|
| `Detect-LocalAdmins.ps1` | Detection script (Exit 1 = Bereinigung nötig) |
| `Remediate-LocalAdmins.ps1` | Remediation script (entfernt unerlaubte Admins) |

## Standard-Allowlist

- `LAPS-Admin` (LAPS, Name anpassen)
- Eingebauter Administrator (RID 500) – Lockout-Schutz
- Entra-Rollen (`S-1-12-1-*`, z. B. Global Admin / Azure AD Joined Device Local Administrator)
- Domänen-Admins / Organisations-Admins (RID 512 / 519) auf domänenbeigetretenen Geräten

Anpassung über den Konfigurationsblock am Anfang **beider** Skripte
(`$AllowedNames`, `$AllowedSids`, `$Keep*`-Schalter). Der Block muss in
Detection und Remediation identisch sein.

## Deployment in Intune

1. Endpoint Manager → **Devices → Remediations → Create**.
2. Detection: `Detect-LocalAdmins.ps1`, Remediation: `Remediate-LocalAdmins.ps1`.
3. **Run this script using the logged-on credentials:** `No` (SYSTEM).
4. **Enforce script signature check:** nach Bedarf.
5. **Run script in 64-bit PowerShell:** `Yes`.
6. Zeitplan zuweisen (z. B. täglich).

## Sicherheitsnetz

Die Remediation bricht ab, wenn nach der Bereinigung **kein** erlaubtes
Admin-Konto übrig bliebe – verhindert kompletten Lockout durch
Fehlkonfiguration der Allowlist.

## Hinweise

- Enumeration/Entfernung erfolgen über den ADSI/WinNT-Provider statt
  `Get-LocalGroupMember`, da letzteres bei nicht auflösbaren Entra-SIDs mit
  `0x80070456` abbricht.
- Vor Rollout auf Pilotgeräten testen und LAPS-Passwortrotation (LAPS)
  sicherstellen.
