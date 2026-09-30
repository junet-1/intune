# Intune scripts for Windows

A collection of Microsoft Intune **Platform Scripts** and **Remediations** for
Windows 11, built for a cloud-only (Entra ID joined, Autopilot) environment.
Every script is self-contained, idempotent and logs to
`C:\ProgramData\IntuneScripts\Logs`.

Per-script documentation lives in the README next to each script.

## Contents

| Folder | Content |
|---|---|
| [PlatformScripts](PlatformScripts) | One-shot device configuration: debloat, Explorer defaults, OEM branding, BIOS security baseline (Dell, HP, Lenovo), default file associations, fonts, shortcuts |
| [Remediations](Remediations) | Detection/remediation pairs: BitLocker, Defender real-time protection, firewall, SMB signing, SMBv1, NetBIOS, LDAP client encryption, UAC, local admin cleanup, Teams cache, uptime reboot reminder |
| [Remediations/_codesign](Remediations/_codesign) | Create a private code signing CA and sign scripts (Windows PowerShell or Linux with osslsigncode) |
| [Apps](Apps) | Build .intunewin packages on Linux without the Win32 Content Prep Tool |

## Naming

The display name in Intune comes from the `.NAME` section of each script
(for remediations: the detection script).

`PS` = platform script, `REM` = remediation, then `D` / `U` for device or user
context, the platform and the purpose, e.g. `PS-D-WIN-BiosBaseline`,
`REM-D-WIN-SmbSigning`.

## Before you deploy

- **Adjust the configuration block** at the top of each script. Placeholders use
  `Contoso` / `contoso.com` / `example.com` (branding, support URL, wallpaper URL,
  shortcut target). `Reset-LocalAdmins` expects the Windows LAPS account name
  `LAPS-Admin`; change it to match your LAPS policy.
- **Sign the scripts** if you enforce `AllSigned`. The scripts in this repository
  are unsigned. See `Remediations/_codesign` for tooling. Deploy your root CA and
  signing certificate to the devices (Trusted Root and Trusted Publisher) before
  the first script runs.
- **Test on pilot devices first.** Several scripts change security-relevant
  settings (UAC, local administrators, BIOS, LDAP).

## License

MIT, see [LICENSE](LICENSE). Some remediations are based on third-party work,
see [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).
