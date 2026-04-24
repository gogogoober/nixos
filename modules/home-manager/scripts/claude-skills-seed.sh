#!/usr/bin/env bash
set -euo pipefail

# Seeds ~/.claude/CLAUDE.md and named skill directories under ~/.claude/skills/
# from a baseline tree shipped via this NixOS config. Invoked automatically by
# home-manager activation, and can be re-run by hand. Per-file-by-name
# semantics: only files/dirs present in the seed are touched, so anything
# Claude or the user added at runtime under ~/.claude/skills/ is left alone.
#
# Seed path comes from CLAUDE_SEED (set by the Nix wrapper), with a
# repo-relative fallback so the raw script stays runnable outside the Nix
# build for testing.

SEED="${CLAUDE_SEED:-}"
if [ -z "$SEED" ]; then
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  SEED="$script_dir/../../../assets/claude"
fi

if [ ! -d "$SEED" ]; then
  echo "claude-skills-seed: seed dir not found at $SEED" >&2
  exit 1
fi

TARGET="${HOME}/.claude"
mkdir -p "$TARGET/skills"

# Drop any prior symlink and overwrite CLAUDE.md from the seed.
if [ -f "$SEED/CLAUDE.md" ]; then
  if [ -L "$TARGET/CLAUDE.md" ]; then
    rm "$TARGET/CLAUDE.md"
  fi
  install -m 644 "$SEED/CLAUDE.md" "$TARGET/CLAUDE.md"
  echo "claude-skills-seed: wrote $TARGET/CLAUDE.md"
fi

# Per-skill overwrite by name: for each directory under $SEED/skills/, replace
# the matching directory under $TARGET/skills/. Skills not present in the seed
# are left untouched.
if [ -d "$SEED/skills" ]; then
  shopt -s nullglob
  for skill_path in "$SEED/skills"/*/; do
    skill_name="$(basename "$skill_path")"
    dest="$TARGET/skills/$skill_name"
    if [ -e "$dest" ] || [ -L "$dest" ]; then
      rm -rf "$dest"
    fi
    cp -r "$skill_path" "$dest"
    # nix-store sources are mode 555; make the local copy writable.
    chmod -R u+w "$dest"
    echo "claude-skills-seed: seeded skill $skill_name"
  done
  shopt -u nullglob
fi
