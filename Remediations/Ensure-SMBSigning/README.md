# Remediation: Ensure SMB Signing

Intune remediation package that makes sure SMB signing is required for both
client and server. Protects against SMB relay and tampering.

## Files

| File | Role in Intune |
|------|----------------|
| Detect-SMBSigning.ps1 | Detection script (exit 1 = signing not required) |
| Remediate-SMBSigning.ps1 | Remediation script (sets RequireSecuritySignature=1) |

## What is set

RequireSecuritySignature = 1 under

- LanmanWorkstation\Parameters (client)
- LanmanServer\Parameters (server)

## Deployment in Intune

1. Intune admin center → Devices → Scripts and remediations → Create.
2. Detection: Detect-SMBSigning.ps1, Remediation: Remediate-SMBSigning.ps1.
3. Run this script using the logged-on credentials: No (SYSTEM).
4. Run script in 64-bit PowerShell: Yes.

## Signing

```bash
./_codesign/sign-scripts.sh <cert-dir> \
  Ensure-SMBSigning/Detect-SMBSigning.ps1 \
  Ensure-SMBSigning/Remediate-SMBSigning.ps1
```

## Origin

Idea adapted from EndpointAnalyticsRemediationScripts (MIT), see
THIRD-PARTY-NOTICES.md. The original used invalid registry paths (HKLM without
the provider colon); fixed here and extended to cover both client and server.
