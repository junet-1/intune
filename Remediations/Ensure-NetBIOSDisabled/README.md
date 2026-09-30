# Remediation: Ensure NetBIOS Disabled

Intune-Remediation-Paket, das NetBIOS über TCP/IP auf allen Netzwerkschnittstellen
deaktiviert hält. NetBIOS-Namensauflösung (NBT-NS) läuft per Broadcast und ohne
Authentifizierung und ist damit der Standardhebel für Name Poisoning und
NTLM-Relay-Angriffe.

Gesteuert wird der Wert NetbiosOptions je Schnittstelle unter
HKLM\SYSTEM\CurrentControlSet\Services\NetBT\Parameters\Interfaces\Tcpip_{GUID}:

| Wert | Bedeutung |
|------|-----------|
| 0 | Einstellung vom DHCP-Server übernehmen |
| 1 | NetBIOS über TCP/IP aktiviert |
| 2 | NetBIOS über TCP/IP deaktiviert (Zielwert) |

Der Wert 0 gilt als nicht konform, weil die Entscheidung sonst beim DHCP-Server
liegt.

## Dateien

| Datei | Rolle in Intune |
|-------|-----------------|
| Detect-NetBIOSDisabled.ps1 | Detection script (Exit 1 = mindestens eine Schnittstelle nicht auf 2) |
| Remediate-NetBIOSDisabled.ps1 | Remediation script (NetbiosOptions=2 auf allen Tcpip_*) |

## Deployment in Intune

1. Endpoint Manager → Devices → Scripts and remediations → Create.
2. Detection: Detect-NetBIOSDisabled.ps1, Remediation: Remediate-NetBIOSDisabled.ps1.
3. Run this script using the logged-on credentials: No (SYSTEM).
4. Run script in 64-bit PowerShell: Yes.

## Wirkung

Bestehende Bindungen behalten ihren Zustand bis zum Adapter-Reset oder Neustart,
neue und neu verbundene Adapter übernehmen den Wert sofort. Der erste Lauf meldet
daher oft noch einmal nicht konform, bis das Gerät neu gestartet wurde.

Vor dem breiten Ausrollen prüfen, ob im Netz noch etwas auf NetBIOS-Namensauflösung
angewiesen ist: WINS, Zugriff auf ältere Freigaben per reinem NetBIOS-Namen sowie
die Netzwerkumgebung im Explorer. Läuft alles über DNS, ist die Abschaltung
unkritisch.

## Signieren

```bash
./_codesign/sign-scripts.sh <cert-dir> \
  Ensure-NetBIOSDisabled/Detect-NetBIOSDisabled.ps1 \
  Ensure-NetBIOSDisabled/Remediate-NetBIOSDisabled.ps1
```
