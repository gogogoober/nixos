#!/usr/bin/env bash
set -euo pipefail

# Overwrites ~/.config/Code/User/settings.json with the declarative seed.
# Invoked automatically by home-manager activation, and can be re-run by hand.
# Seed path comes from the Nix wrapper via VSCODE_SEED; fall back to a repo-relative
# path so the raw script stays runnable outside the Nix build for testing.

SEED="${VSCODE_SEED:-}"
if [ -z "$SEED" ]; then
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  SEED="$script_dir/../../../utils/vscode-settings-seed.json"
fi

if [ ! -f "$SEED" ]; then
  echo "vscode-settings-seed: seed file not found at $SEED" >&2
  exit 1
fi

TARGET="${HOME}/.config/Code/User/settings.json"
mkdir -p "$(dirname "$TARGET")"

# Drop any leftover symlink from a previous Home Manager generation that
# managed settings.json declaratively via the nix store.
if [ -L "$TARGET" ]; then
  rm "$TARGET"
fi

install -m 644 "$SEED" "$TARGET"
echo "vscode-settings-seed: wrote $TARGET"
