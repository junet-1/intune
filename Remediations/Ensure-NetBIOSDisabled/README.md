# Remediation: Ensure NetBIOS Disabled

Intune remediation package that keeps NetBIOS over TCP/IP turned off on all
network interfaces. NetBIOS name resolution (NBT-NS) works by broadcast and
without authentication, which makes it the standard lever for name poisoning and
NTLM relay attacks.

The script manages the value NetbiosOptions per interface under
`HKLM\SYSTEM\CurrentControlSet\Services\NetBT\Parameters\Interfaces\Tcpip_{GUID}`:

| Value | Meaning |
|-------|---------|
| 0 | Use the setting from the DHCP server |
| 1 | NetBIOS over TCP/IP enabled |
| 2 | NetBIOS over TCP/IP disabled (target value) |

Value 0 counts as non-compliant, because the decision would otherwise be left to
the DHCP server.

## Files

| File | Role in Intune |
|------|----------------|
| Detect-NetBIOSDisabled.ps1 | Detection script (exit 1 = at least one interface not set to 2) |
| Remediate-NetBIOSDisabled.ps1 | Remediation script (NetbiosOptions=2 on all Tcpip_*) |

## Deployment in Intune

1. Intune admin center → Devices → Scripts and remediations → Create.
2. Detection: Detect-NetBIOSDisabled.ps1, Remediation: Remediate-NetBIOSDisabled.ps1.
3. Run this script using the logged-on credentials: No (SYSTEM).
4. Run script in 64-bit PowerShell: Yes.

## Effect

Existing bindings keep their state until an adapter reset or reboot; new and
reconnected adapters pick up the value immediately. The first run therefore often
reports non-compliant once more until the device has restarted.

Before a broad rollout, check whether anything in the network still depends on
NetBIOS name resolution: WINS, access to older shares by plain NetBIOS name, and
network browsing in Explorer. If everything resolves via DNS, turning it off is
safe.

## Signing

```bash
./_codesign/sign-scripts.sh <cert-dir> \
  Ensure-NetBIOSDisabled/Detect-NetBIOSDisabled.ps1 \
  Ensure-NetBIOSDisabled/Remediate-NetBIOSDisabled.ps1
```
