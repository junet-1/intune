# Remediation: Ensure Core Services

Intune remediation package that monitors important services and starts or
re-enables them when they are disabled or stopped. By default:

- ClickToRunSvc (Office Click-to-Run)
- wuauserv (Windows Update)

## Files

| File | Role in Intune |
|------|----------------|
| Detect-CoreServices.ps1 | Detection script (exit 1 = service disabled or stopped) |
| Remediate-CoreServices.ps1 | Remediation script (sets start type, starts the service) |

## Configuration

The service list lives in the config block at the top of both scripts; keep them
identical. Per service: Name, DesiredStartType, EnsureRunning. Services that aren't
installed are skipped (e.g. ClickToRunSvc on devices without Click-to-Run Office).

## Note on wuauserv

wuauserv is trigger-started and is intentionally stopped during normal operation.
With EnsureRunning = true the detection therefore reports the service as
non-compliant in most cycles and starts it every time. That's harmless but adds
noise to reporting. If you only want to protect against an accidental or
tampered Disabled state, set EnsureRunning to false for wuauserv.

## Deployment in Intune

1. Intune admin center → Devices → Scripts and remediations → Create.
2. Detection: Detect-CoreServices.ps1, Remediation: Remediate-CoreServices.ps1.
3. Run this script using the logged-on credentials: No (SYSTEM).
4. Run script in 64-bit PowerShell: Yes.

## Signing

```bash
./_codesign/sign-scripts.sh <cert-dir> \
  Ensure-CoreServices/Detect-CoreServices.ps1 \
  Ensure-CoreServices/Remediate-CoreServices.ps1
```
