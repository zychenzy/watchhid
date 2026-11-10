#!/usr/bin/env bash
# Tracked preflight for a local signed WatchHID build.
# Checks tools, gitignored Config/Developer.xcconfig, and a usable
# Apple Development identity (certificate + private key on this Mac).
# Does not print UDIDs, Bluetooth addresses, certificate serials,
# emails, or private key material. Does not create, revoke, export,
# or delete Apple Development certificates.
#
# Usage:
#   ./scripts/check-signing-prereqs.sh
#   ./scripts/check-signing-prereqs.sh --install-wwdr
#
# --install-wwdr downloads Apple's official WWDR G3 intermediate and
# installs it into the login keychain. macOS will usually ask for the
# login keychain password or an Allow prompt. Confirming that dialog
# authorizes writing the official intermediate; it does not create an
# Apple Development certificate.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

WWDR_URL="https://www.apple.com/certificateauthority/AppleWWDRCAG3.cer"
WWDR_NAME="AppleWWDRCAG3.cer"

install_wwdr_g3() {
  tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/watchhid-wwdr.XXXXXX")"
  trap 'rm -rf "$tmpdir"' RETURN
  dest="$tmpdir/$WWDR_NAME"
  echo "Downloading official WWDR G3 from Apple PKI..."
  if ! curl -fsSL "$WWDR_URL" -o "$dest"; then
    echo "Could not download $WWDR_URL" >&2
    return 1
  fi
  if ! openssl x509 -inform DER -in "$dest" -noout -subject >/dev/null 2>&1; then
    echo "The downloaded file was not a readable DER certificate. Not installing it." >&2
    return 1
  fi
  echo "Installing into the login keychain. If macOS asks for the login password or Allow, confirm it in that official dialog."
  echo "That prompt authorizes Apple's official intermediate; it is not creating a Development certificate."
  echo "Do not set trust to Always Trust, and do not revoke or delete any Development certificate."
  security add-certificates -k "$HOME/Library/Keychains/login.keychain-db" "$dest"
  echo "WWDR G3 is in the login keychain."
}

if [[ "${1:-}" == "--install-wwdr" ]]; then
  install_wwdr_g3
  shift
elif [[ -n "${1:-}" ]]; then
  echo "Usage: $0 [--install-wwdr]" >&2
  exit 2
fi

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

# A valid identity is a certificate plus a matching private key that also
# passes trust evaluation. A .cer can be in the login keychain (Xcode
# Manage Certificates status blank, not "Not in Keychain") and still fail
# find-identity -v, either because the private key is missing or because
# the WWDR G3 intermediate is missing. This script does not print
# identity names, emails, or serials.
identity_out="$(security find-identity -v -p codesigning 2>/dev/null || true)"
if printf '%s\n' "$identity_out" | grep -q 'Apple Development'; then
  echo "Apple Development signing identity: ok"
else
  missing=1
  # Without -v: includes identities that exist but are not trusted.
  identity_all="$(security find-identity -p codesigning 2>/dev/null || true)"
  identity_basic="$(security find-identity 2>/dev/null || true)"
  cert_out="$(security find-certificate -a -c 'Apple Development' 2>/dev/null || true)"
  if printf '%s\n' "$identity_all$identity_basic" | grep -q 'Apple Development'; then
    echo "An Apple Development identity is present, but it is not valid for codesigning (find-identity -v listed none)." >&2
    if printf '%s\n' "$identity_all$identity_basic" | grep -q 'CSSMERR_TP_NOT_TRUSTED'; then
      echo "The certificate is paired with a private key on this Mac; trust evaluation failed (CSSMERR_TP_NOT_TRUSTED). This is often a missing WWDR G3 intermediate, not a missing key." >&2
      echo "Install Apple's official WWDR G3 intermediate into the login keychain with:" >&2
      echo "  ./scripts/check-signing-prereqs.sh --install-wwdr" >&2
      echo "macOS will usually ask for the login keychain password or an Allow prompt; confirm it in the official dialog. That authorizes installing Apple's official intermediate, and is not creating a new Apple Development certificate." >&2
      echo "Do not set custom trust to Always Trust, do not revoke or delete the Apple Development certificate, and do not import a private key from another Mac." >&2
    else
      echo "A paired identity exists but is not valid. Check certificate trust and the WWDR G3 intermediate before creating or revoking certificates." >&2
    fi
    echo "Do not click + in Manage Certificates until this is ruled out. If Xcode says you already have a current Development certificate or a pending request, stop; do not revoke another machine's certificate." >&2
    echo "Then run: ./scripts/check-signing-prereqs.sh" >&2
  elif printf '%s\n' "$cert_out" | grep -q '"labl"<blob>="Apple Development'; then
    echo "An Apple Development certificate is in the keychain, but it is not a signing identity: no paired private key was found on this Mac." >&2
    echo "Importing or creating only a .cer is not enough. Do not revoke or delete the existing certificate, and do not export or copy a private key from another Mac." >&2
    echo "On this Mac, open Xcode > Settings > Accounts, select the project Apple ID and the same team, open Manage Certificates…, and use + to add Apple Development so this Mac generates the private key." >&2
    echo "If a Keychain access or Apple ID dialog appears, confirm it in that official window. If Xcode says you already have a current Development certificate or a pending request, or that the team is at the certificate limit, stop; do not revoke another machine's certificate." >&2
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
