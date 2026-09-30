# Windows Platform Scripts

Standalone Intune platform scripts (Devices → Scripts and remediations →
Platform scripts). Every script is self-contained, idempotent and runs as
SYSTEM. Logs go to `C:\ProgramData\IntuneScripts\Logs`. Exit 0 = success,
non-zero = failure (Intune retries).

## Scripts

| Script                               | Intune name                      | Category    | Purpose                                                                                                         |
|--------------------------------------|----------------------------------|-------------|-----------------------------------------------------------------------------------------------------------------|
| PS-D-WIN-AutoAcceptSSO.ps1           | PS-D-WIN-AutoAcceptSSO           | UX/Config   | Checks and sets `AutoAcceptSsoPermission=1` as a machine-wide Windows AAD policy                                |
| PS-D-WIN-TimeZoneAuto.ps1            | PS-D-WIN-TimeZoneAuto            | UX/Config   | Automatic time zone (location service + tzautoupdate)                                                           |
| PS-D-WIN-PowerConfig.ps1             | PS-D-WIN-PowerConfig             | UX/Config   | No sleep on AC power, configurable display timeout                                                              |
| PS-D-WIN-ExplorerDefaults.ps1        | PS-D-WIN-ExplorerDefaults        | UX/Config   | Show file extensions, Explorer opens "This PC" – for all existing and future users                              |
| PS-D-WIN-DisableConsumerFeatures.ps1 | PS-D-WIN-DisableConsumerFeatures | Debloat     | Turns off consumer and advertising content, Spotlight tips, widgets                                             |
| PS-D-WIN-RemoveConsumerBloat.ps1     | PS-D-WIN-RemoveConsumerBloat     | Debloat     | Removes consumer apps (provisioned and for all users), guarded by a protected list                              |
| PS-D-WIN-DefaultAppAssociations.ps1  | PS-D-WIN-DefaultAppAssociations  | UX/Config   | Imports default file associations via DISM (PDF → Adobe Acrobat Reader DC, script formats → Notepad++)          |
| PS-D-WIN-ScriptFileSafety.ps1        | PS-D-WIN-ScriptFileSafety        | Hardening   | Makes Notepad++ the default verb for executable text formats and can turn off Windows Script Host               |
| PS-D-WIN-BiosBaseline.ps1            | PS-D-WIN-BiosBaseline            | Hardening   | Turns on firmware security features through the vendor BIOS interface (Dell, HP, Lenovo)                        |
| PS-D-WIN-SystemTweaks.ps1            | PS-D-WIN-SystemTweaks            | UX/Config   | Small machine-wide interface tweaks                                                                             |
| PS-D-WIN-OemBranding.ps1             | PS-D-WIN-OemBranding             | UX/Config   | Sets manufacturer, support info, logo and registered owner shown under System > About                           |
| PS-D-WIN-DesktopLockScreen.ps1       | PS-D-WIN-DesktopLockScreen       | UX/Config   | Sets desktop background and lock screen image via PersonalizationCSP                                            |
| PS-D-WIN-CreateShortcut.ps1          | PS-D-WIN-CreateShortcut          | Deployment  | Creates an all-users shortcut (desktop / Start menu)                                                            |
| PS-D-WIN-InstallFonts.ps1            | PS-D-WIN-InstallFonts            | Deployment  | Installs fonts machine-wide                                                                                     |
| PS-D-WIN-WindowsFeatures.ps1         | PS-D-WIN-WindowsFeatures         | UX/Config   | Adds, disables and removes Windows features                                                                     |

The Intune display name is taken from the `.NAME` section of each script. Scheme:
`PS` for platform script, `REM` for remediation, `D` or `U` for device or user
context, then platform and purpose.

## Standard deployment

1. Intune admin center → Devices → Scripts and remediations → Platform scripts → Add → Windows 10 and later.
2. Upload the script file.
3. Run this script using the logged-on credentials: No (SYSTEM).
4. Enforce script signature check: as required.
5. Run script in 64-bit PowerShell Host: Yes.
6. Assign.

## Notes per script

- **PS-D-WIN-ExplorerDefaults:** takes effect for signed-in users only after sign-out/sign-in or an Explorer restart. New users inherit the values through the default profile.
- **PS-D-WIN-RemoveConsumerBloat:** review the target and protected lists in the configuration block before rollout. Names support wildcards; the protected list wins over an overly broad pattern. If apps are also removed via Settings Catalog or Autopilot branding, keep the lists aligned, otherwise policy and script work against each other.
- **PS-D-WIN-CreateShortcut:** adjust the parameter defaults, or deploy several copies with different values. Platform scripts don't accept parameters, so set the values inside the script.
- **PS-D-WIN-DefaultAppAssociations:** DISM writes the associations to the default profile, so they apply to profiles created afterwards. Adobe Acrobat Reader DC and Notepad++ must be installed before the first sign-in, otherwise Windows falls back to its own defaults. Assign both as required apps and make them blocking apps in the ESP.
- **PS-D-WIN-ScriptFileSafety:** optional. Only needed where the DISM import isn't enough, i.e. for existing profiles and for bat/cmd, which Windows doesn't reliably route through the default associations. Writes machine-wide under `HKLM\SOFTWARE\Classes` and applies immediately to all users. The previous default verb is stored under `HKLM\SOFTWARE\IntuneScripts\FileTypeSafety` so the change can be reverted. Only runs once Notepad++ is installed; otherwise exit 1 and Intune retries. The switch `$DisableWindowsScriptHost` is `$false` by default – it goes beyond protecting against accidental double-clicks and breaks vbs/js calls.
- **Scope of the associations:** they only change what the default verb triggers, i.e. double-click and ShellExecute. `cmd /c`, `wscript`, `powershell -File` and the "Run" context menu entry are not affected. If an application launches a bat file through ShellExecute instead of CreateProcess, it now opens in Notepad++ – check line-of-business apps before rollout. Blocking actual execution is the job of Attack Surface Reduction rules and the AllSigned execution policy. A user choice made via "Open with → Always" still wins for that user and extension.
- **PS-D-WIN-BiosBaseline, how it writes:** depending on the vendor via `root\dcim\sysman\biosattributes` (Dell, agentless WMI-ACPI) or `root\dell\sysman` (Dell Command | Monitor as fallback), `root\hp\instrumentedBIOS` (HP), or `root\wmi` with `Lenovo_SetBiosSetting` followed by `Lenovo_SaveBiosSettings`. Attribute names differ per vendor and model, so none is hard-coded: the script reads the available attributes, takes the first match from the vendor's candidate list and otherwise falls back to pattern matching. The value to write comes from the attribute's own list of allowed values, so Enabled, Enable, Active and Available all work.
- **PS-D-WIN-BiosBaseline, scope:** the `$Features` table in the configuration block controls everything. Included are VT-d, VT-x, TPM visible and active, DMA protection, SMM mitigation, memory encryption and Intel TXT – only features without operational risk. For each row the script reads the current state, leaves an enabled feature alone and turns on a disabled one. None of this changes boot behavior, and the TPM is never cleared: names containing clear, reset, erase and similar are always excluded from matching, so a broad pattern can't land on a wipe switch. Missing features are logged and skipped, as are read-only attributes and values that read as neither on nor off.
- **PS-D-WIN-BiosBaseline, operation:** if a BIOS password is set, put it in `$BiosPassword`, otherwise the firmware rejects every write. On the native Dell path the script checks this upfront via `PasswordObject` in `root\dcim\sysman\wmisecurity` and aborts with a clear message instead of an opaque status code. Before the first write, BitLocker on the system drive is suspended for one reboot, because the changed PCR measurements would otherwise send the device into recovery. The settings take effect at the next reboot, which you schedule separately. Exit 1 on a missing provider, a rejected write or missing TXT – TXT is the only row marked as required, because some firmwares only expose it after VT-x and VT-d are on. The first run then enables the prerequisites, and the Intune retry after the reboot finds TXT and completes.
- **PS-D-WIN-BiosBaseline, why TXT:** TXT is the prerequisite for System Guard Secure Launch (DRTM). Without the matching VBS setting in Intune the feature stays unused.
- **PS-D-WIN-InstallFonts:** put the font files in a `Fonts` subfolder next to the script. Platform scripts only upload a single .ps1; for accompanying files, package it as a Win32 app (.intunewin) instead.

## Signing

Sign before distribution (mandatory with AllSigned):

```bash
./../Remediations/_codesign/sign-scripts.sh <cert-dir> \
  PS-D-WIN-AutoAcceptSSO.ps1 PS-D-WIN-TimeZoneAuto.ps1 PS-D-WIN-PowerConfig.ps1 PS-D-WIN-ExplorerDefaults.ps1 \
  PS-D-WIN-DisableConsumerFeatures.ps1 PS-D-WIN-CreateShortcut.ps1 PS-D-WIN-InstallFonts.ps1 \
  PS-D-WIN-DefaultAppAssociations.ps1 PS-D-WIN-ScriptFileSafety.ps1 PS-D-WIN-BiosBaseline.ps1
```
