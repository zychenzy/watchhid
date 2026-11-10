#!/usr/bin/env bash
# Tracked preflight for a local signed WatchHID build.
# Checks tools, gitignored Config/Developer.xcconfig, and a usable
# Apple Development identity (certificate + private key on this Mac).
# Does not print UDIDs, Bluetooth addresses, certificate serials,
# emails, or private key material. Does not create, revoke, export,
# or delete certificates.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
missing=0

if ! command -v xcodegen >/dev/null; then
  echo "Missing xcodegen. On this Mac: brew install xcodegen" >&2
  missing=1
else
  echo "xcodegen: ok"
fi

if ! command -v xcodebuild >/dev/null; then
  echo "Missing xcodebuild. Install full Xcode and run: sudo xcode-select -s /Applications/Xcode.app" >&2
  missing=1
else
  echo "xcodebuild: ok"
fi

XCCONFIG="$ROOT/Config/Developer.xcconfig"
EXAMPLE="$ROOT/Config/Developer.xcconfig.example"
if [[ ! -f "$XCCONFIG" ]]; then
  echo "Missing Config/Developer.xcconfig (gitignored)." >&2
  echo "Copy the tracked template and fill DEVELOPMENT_TEAM with the team shown in Xcode > Settings > Accounts:" >&2
  echo "  cp $EXAMPLE $XCCONFIG" >&2
  echo "Do not commit Config/Developer.xcconfig, local_devices.env, .p12, .cer, or provisioning profiles." >&2
  missing=1
elif ! grep -qE '^DEVELOPMENT_TEAM *= *[A-Z0-9]+' "$XCCONFIG"; then
  echo "Config/Developer.xcconfig exists, but DEVELOPMENT_TEAM is missing or still a placeholder." >&2
  echo "Set it to the team ID shown in Xcode for the project Apple ID. Do not invent a new team." >&2
  missing=1
else
  echo "Config/Developer.xcconfig: DEVELOPMENT_TEAM is set"
fi

# Identity = certificate + matching private key. A downloaded .cer can be
# in the login keychain and still not be a signing identity.
identity_out="$(security find-identity -v -p codesigning 2>/dev/null || true)"
if printf '%s\n' "$identity_out" | grep -q 'Apple Development'; then
  echo "Apple Development signing identity: ok"
else
  missing=1
  cert_out="$(security find-certificate -a -c 'Apple Development' 2>/dev/null || true)"
  if printf '%s\n' "$cert_out" | grep -q '"labl"<blob>="Apple Development'; then
    echo "An Apple Development certificate is in the keychain, but it is not a valid signing identity: the matching private key is not on this Mac." >&2
    echo "Importing or creating only a .cer is not enough. Do not revoke or delete the existing certificate, and do not export or copy a private key from another Mac." >&2
    echo "On this Mac, open Xcode > Settings > Accounts, select the project Apple ID and the same team, open Manage Certificates…, and use + to add Apple Development so this Mac generates the private key." >&2
    echo "If a Keychain access or Apple ID dialog appears, confirm it in that official window. If Xcode says the team is at the certificate limit, stop; do not revoke another machine's certificate." >&2
    echo "Then run: ./scripts/check-signing-prereqs.sh" >&2
  else
    echo "No Apple Development signing identity on this Mac." >&2
    echo "On this Mac, open Xcode > Settings > Accounts, sign in with the project Apple ID (the macOS login may stay different), select the same team, open Manage Certificates…, and use + to add Apple Development." >&2
    echo "Confirm any Keychain or Apple ID dialog in the official window. Do not send passwords or codes in chat. Do not copy private keys from another Mac." >&2
    echo "Then run: ./scripts/check-signing-prereqs.sh" >&2
  fi
fi

if [[ "$missing" -ne 0 ]]; then
  echo "Signing prerequisites are not ready. Fix the items above, then run ./scripts/ship-encrypted-hogp.sh on this machine. A still-valid pre-signed zip can be installed without a local cert, but that is not the preferred rebuild path once the project is on this Mac." >&2
  exit 1
fi

echo "Signing prerequisites are ready for a local ./scripts/ship-encrypted-hogp.sh build."
