# Remediation: Clear Teams Cache

Intune remediation package that cleans up a bloated Teams cache of the signed-in
user. Fixes typical Teams issues (slow, hangs at sign-in, shows stale content).

## Context

Runs in user context (runAsAccount = user) because the cache lives in the user
profile. If Teams is running, the remediation skips the cleanup so it doesn't
disrupt an active session; the next cycle cleans up once Teams is closed.

## Files

| File | Role in Intune |
|------|----------------|
| Detect-TeamsCache.ps1 | Detection script (exit 1 = cache larger than threshold) |
| Remediate-TeamsCache.ps1 | Remediation script (clears the cache when Teams is closed) |

## Configuration

MaxCacheMB (default 500) at the top of both scripts; keep them identical.

## Deployment in Intune

1. Intune admin center → Devices → Scripts and remediations → Create.
2. Detection: Detect-TeamsCache.ps1, Remediation: Remediate-TeamsCache.ps1.
3. Run this script using the logged-on credentials: Yes (user context).
4. Run script in 64-bit PowerShell: Yes.

## Signing

```bash
./_codesign/sign-scripts.sh <cert-dir> \
  Clear-TeamsCache/Detect-TeamsCache.ps1 \
  Clear-TeamsCache/Remediate-TeamsCache.ps1
```

## Origin

Idea adapted from EndpointAnalyticsRemediationScripts (MIT), see
THIRD-PARTY-NOTICES.md. Rewritten with threshold-based detection, protection
against a running Teams and support for classic and new Teams.
