# Remediation: Reboot Reminder (Uptime)

Intune remediation package that reminds users to restart when a device has been
running too long without a reboot. It deliberately never restarts the device, it
only reminds.

## Context

Runs in user context (runAsAccount = user) so the reminder appears as a toast for
the signed-in user. If the toast fails, a message via msg.exe is shown instead
(available on Pro/Enterprise).

## Files

| File | Role in Intune |
|------|----------------|
| Detect-UptimeReboot.ps1 | Detection script (exit 1 = uptime above threshold) |
| Remediate-UptimeReboot.ps1 | Remediation script (shows a reminder, no reboot) |

## Configuration

MaxUptimeDays (default 7) at the top of both scripts; keep them identical.

## Deployment in Intune

1. Intune admin center → Devices → Scripts and remediations → Create.
2. Detection: Detect-UptimeReboot.ps1, Remediation: Remediate-UptimeReboot.ps1.
3. Run this script using the logged-on credentials: Yes (user context).
4. Run script in 64-bit PowerShell: Yes.

## Note

Intentionally no forced reboot – devices should never restart without the user's
action. The toast uses WinRT and runs under Windows PowerShell 5.1, which Intune
uses by default.
