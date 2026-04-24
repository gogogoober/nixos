#!/usr/bin/env bash
set -euo pipefail

# Seeds ~/.claude/{CLAUDE.md, skills/<named>} from assets/claude/.
# Per-name overwrite: anything not in the seed is untouched.
# CLAUDE_SEED is set by the Nix wrapper; fallback lets the raw script run standalone.

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

if [ -f "$SEED/CLAUDE.md" ]; then
  if [ -L "$TARGET/CLAUDE.md" ]; then
    rm "$TARGET/CLAUDE.md"
  fi
  install -m 644 "$SEED/CLAUDE.md" "$TARGET/CLAUDE.md"
  echo "claude-skills-seed: wrote $TARGET/CLAUDE.md"
fi

if [ -d "$SEED/skills" ]; then
  shopt -s nullglob
  for skill_path in "$SEED/skills"/*/; do
    skill_name="$(basename "$skill_path")"
    dest="$TARGET/skills/$skill_name"
    if [ -e "$dest" ] || [ -L "$dest" ]; then
      rm -rf "$dest"
    fi
    cp -r "$skill_path" "$dest"
    # nix-store sources are mode 555
    chmod -R u+w "$dest"
    echo "claude-skills-seed: seeded skill $skill_name"
  done
  shopt -u nullglob
fi
