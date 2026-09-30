#!/usr/bin/env bash
# Sign PowerShell scripts with osslsigncode (Authenticode) on Linux.
# Re-run whenever a script changes - the signature covers the file content.
#
# Usage:  ./sign-scripts.sh <cert-dir> <file.ps1> [more.ps1 ...]
#   <cert-dir> holds codesign.crt/.key and codesign-root.crt
#
# Requires: osslsigncode (apt install osslsigncode)
set -euo pipefail

CERTDIR="${1:?path to cert dir}"; shift
TS_URL="http://timestamp.digicert.com"   # RFC3161 timestamp server (SHA-256)

CRT="$CERTDIR/codesign.crt"
KEY="$CERTDIR/codesign.key"
ROOT="$CERTDIR/codesign-root.crt"

for f in "$@"; do
  # -u: only reserve a name; osslsigncode refuses to overwrite an existing file.
  tmp="$(mktemp -u --suffix=.ps1)"
  echo ">> Signing $f"
  osslsigncode sign \
    -certs "$CRT" -key "$KEY" -ac "$ROOT" \
    -h sha256 \
    -n "Intune Script" \
    -i "https://www.contoso.com" \
    -ts "$TS_URL" \
    -in "$f" -out "$tmp"
  mv "$tmp" "$f"                 # sign in place
  # Verify against our own root, not the system store - the private root is not in
  # a stock Linux truststore, and without -CAfile this prints a misleading
  # "self-signed certificate in certificate chain" failure for a valid signature.
  osslsigncode verify -CAfile "$ROOT" "$f" | grep -E "Signature|Timestamp|Number of" || true
done
echo ">> All signed."
