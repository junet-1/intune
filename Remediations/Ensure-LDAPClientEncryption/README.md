# Remediation: Ensure LDAP Client Encryption

Intune-Remediation-Paket, das für LDAP-Verbindungen des Windows-Clients
Verschlüsselung (Sealing bzw. TLS) erzwingt. Schützt Verzeichnisdaten und
Anmeldeinformationen bei der Übertragung. Ergänzt LDAP Client Signing, ersetzt
es nicht.

## Dateien

| Datei | Rolle in Intune |
|-------|-----------------|
| Detect-LDAPClientEncryption.ps1 | Detection script (Exit 1 = Verschlüsselung nicht erzwungen) |
| Remediate-LDAPClientEncryption.ps1 | Remediation script (setzt LDAPClientConfidentiality=2) |

## Was gesetzt wird

LDAPClientConfidentiality = 2 (DWORD) unter
HKLM\SYSTEM\CurrentControlSet\Services\ldap

| Wert | Bedeutung |
|------|-----------|
| 0 | None |
| 1 | Negotiate (Standard) |
| 2 | Require |

Wirksam ab der nächsten LDAP-Verbindung, kein Neustart nötig. Ausgewertet ab
Windows 11 24H2; ältere Builds ignorieren den Wert.

Mit Require schlagen LDAP-Verbindungen zu Servern fehl, die weder Sealing noch
TLS anbieten (z. B. einfache LDAP-Binds gegen Drittsysteme auf Port 389).

## Deployment in Intune

1. Endpoint Manager → Devices → Scripts and remediations → Create.
2. Detection: Detect-LDAPClientEncryption.ps1, Remediation: Remediate-LDAPClientEncryption.ps1.
3. Run this script using the logged-on credentials: No (SYSTEM).
4. Run script in 64-bit PowerShell: Yes.

## Signieren

```bash
./_codesign/sign-scripts.sh <cert-dir> \
  Ensure-LDAPClientEncryption/Detect-LDAPClientEncryption.ps1 \
  Ensure-LDAPClientEncryption/Remediate-LDAPClientEncryption.ps1
```

## Herkunft

Adaptiert von pariswells.com, "Encrypt LDAP client traffic to protect
sensitive data in transit (Intune)", angepasst an Logging und Namensschema der
übrigen Remediations dieser Sammlung.
