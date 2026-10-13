#!/usr/bin/env bash
# Load the fork's Android release keystore into GitHub Actions secrets so
# `.github/workflows/build.yml` can sign APKs on a tag push.
#
# Needs a token that can write Actions secrets (classic PAT with `repo`, or a
# fine-grained token with Administration: Read and write on this repository).
# The cloud agent's push token cannot set secrets.
#
# Usage:
#   scripts/release/set-android-signing-secrets.sh /path/to/app.key /path/to/key.properties
#
# Or with the files this environment already used for local F-Droid builds:
#   scripts/release/set-android-signing-secrets.sh \
#     /tmp/sbm-release-keys/app.key \
#     /tmp/sbm-release-keys/key.properties.bak

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <app.key> <key.properties>" >&2
  exit 2
fi

keystore="$1"
properties="$2"

if [[ ! -f "$keystore" ]]; then
  echo "keystore not found: $keystore" >&2
  exit 1
fi
if [[ ! -f "$properties" ]]; then
  echo "key.properties not found: $properties" >&2
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "gh is required" >&2
  exit 1
fi

# storeFile is rewritten in CI to app.key next to the decoded keystore; strip
# any absolute developer path so the secret is portable.
props="$(mktemp)"
trap 'rm -f -- "$props"' EXIT
sed -E '/^[[:space:]]*storeFile[[:space:]]*=/d' "$properties" > "$props"
echo 'storeFile=app.key' >> "$props"

echo "Setting ANDROID_KEYSTORE_BASE64 from $keystore"
base64 -w0 "$keystore" | gh secret set ANDROID_KEYSTORE_BASE64

echo "Setting ANDROID_KEY_PROPERTIES from $properties"
gh secret set ANDROID_KEY_PROPERTIES < "$props"

echo "Done. Push a v1.0.<build> tag (or re-run the failed Flutter Build workflow) to publish."
