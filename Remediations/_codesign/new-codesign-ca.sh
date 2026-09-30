#!/usr/bin/env bash
# Generate a code signing Root CA + leaf certificate on Linux (OpenSSL only).
# Output:
#   codesign-root.crt   -> deploy to devices (Trusted Root Certification Authorities)
#   codesign.crt/.key   -> leaf, used to sign scripts (keep the .key secret!)
#   codesign.pfx        -> leaf bundle for backup / import elsewhere
set -euo pipefail

OUT="${1:-./out}"                 # output directory
ORG="Contoso"
ROOT_CN="Contoso Code Signing Root CA"
LEAF_CN="Contoso Script Signing"
ROOT_DAYS=3650                    # 10y
LEAF_DAYS=1095                    # 3y
# Resolve to an absolute path BEFORE we cd into $OUT, otherwise the relative
# path no longer points at the ext file.
EXT="$(cd "$(dirname "$0")" && pwd)/codesign.ext"

mkdir -p "$OUT"; cd "$OUT"

echo ">> Root CA"
openssl req -x509 -newkey rsa:4096 -sha256 -days "$ROOT_DAYS" -nodes \
  -keyout codesign-root.key -out codesign-root.crt \
  -subj "/C=DE/O=$ORG/CN=$ROOT_CN" \
  -addext "basicConstraints=critical,CA:TRUE,pathlen:0" \
  -addext "keyUsage=critical,keyCertSign,cRLSign"

echo ">> Leaf key + CSR"
openssl req -new -newkey rsa:4096 -sha256 -nodes \
  -keyout codesign.key -out codesign.csr \
  -subj "/C=DE/O=$ORG/CN=$LEAF_CN"

echo ">> Sign leaf with Root CA (codeSigning EKU)"
openssl x509 -req -in codesign.csr -sha256 -days "$LEAF_DAYS" \
  -CA codesign-root.crt -CAkey codesign-root.key -CAcreateserial \
  -extfile "$EXT" -extensions v3_codesign \
  -out codesign.crt

echo ">> PFX bundle (backup)"
openssl pkcs12 -export -out codesign.pfx \
  -inkey codesign.key -in codesign.crt -certfile codesign-root.crt \
  -passout pass:

rm -f codesign.csr
echo ">> Done. Files in: $OUT"
ls -l
