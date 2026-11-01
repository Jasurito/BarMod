#!/bin/bash
# Sets up a self-signed code-signing identity in a private keychain under .signing/.
# macOS ties the Accessibility grant to the signing identity. With ad-hoc signing
# every rebuild would lose it. Your login keychain is left untouched.
#
# Local builds generate an identity. Release builds import the published one from
# SIGNING_P12_BASE64 and SIGNING_P12_PASSWORD, and CI refuses to generate one,
# because a new identity would make every user allow Accessibility again.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIR="$ROOT/.signing"
KEYCHAIN="$DIR/barmod-signing.keychain-db"
[[ -f "$KEYCHAIN" ]] && exit 0

umask 077
mkdir -p "$DIR"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASSWORD="$(/usr/bin/openssl rand -hex 24)"
printf '%s' "$PASSWORD" > "$DIR/keychain-password"

if [[ -n "${SIGNING_P12_BASE64:-}" ]]; then
  printf '%s' "$SIGNING_P12_BASE64" | base64 -D > "$TMP/identity.p12"
  P12_PASSWORD="${SIGNING_P12_PASSWORD:?SIGNING_P12_PASSWORD is required with SIGNING_P12_BASE64}"
elif [[ -n "${CI:-}" ]]; then
  echo "CI builds need SIGNING_P12_BASE64 and SIGNING_P12_PASSWORD." >&2
  exit 1
else
  cat > "$TMP/cert.cnf" <<'CONFIG'
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = BarMod Local Signing
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
CONFIG

  /usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -keyout "$TMP/key.pem" -out "$TMP/cert.pem" -config "$TMP/cert.cnf" 2>/dev/null
  /usr/bin/openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
    -out "$TMP/identity.p12" -passout "pass:$PASSWORD"
  P12_PASSWORD="$PASSWORD"
fi

# create-keychain adds to the user's search list, so restore the list afterwards.
SEARCH_LIST=()
while IFS= read -r line; do
  line="${line//\"/}"
  SEARCH_LIST+=("${line#"${line%%[![:space:]]*}"}")
done < <(security list-keychains -d user)

security create-keychain -p "$PASSWORD" "$KEYCHAIN"
security list-keychains -d user -s "${SEARCH_LIST[@]}"
security set-keychain-settings "$KEYCHAIN"
security unlock-keychain -p "$PASSWORD" "$KEYCHAIN"
security import "$TMP/identity.p12" -k "$KEYCHAIN" -P "$P12_PASSWORD" -T /usr/bin/codesign >/dev/null
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$PASSWORD" "$KEYCHAIN" >/dev/null
echo "Set up signing identity in $KEYCHAIN"
