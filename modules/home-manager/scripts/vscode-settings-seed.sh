#!/usr/bin/env bash
set -euo pipefail

# Overwrites ~/.config/Code/User/settings.json from the declarative seed.
# VSCODE_SEED is set by the Nix wrapper; fallback lets the raw script run standalone.

SEED="${VSCODE_SEED:-}"
if [ -z "$SEED" ]; then
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  SEED="$script_dir/../../../assets/vscode/settings.json"
fi

if [ ! -f "$SEED" ]; then
  echo "vscode-settings-seed: seed file not found at $SEED" >&2
  exit 1
fi

TARGET="${HOME}/.config/Code/User/settings.json"
mkdir -p "$(dirname "$TARGET")"

# Drop stale symlink from a previous HM generation
if [ -L "$TARGET" ]; then
  rm "$TARGET"
fi

install -m 644 "$SEED" "$TARGET"
echo "vscode-settings-seed: wrote $TARGET"
