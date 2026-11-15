#!/usr/bin/env bash
# Usage: inventory.sh [keyword...]   run from the repo root
set -euo pipefail

host=$(hostname)
host_dir="hosts/$host"
host_doc="docs/hosts/$host.md"
max_hits=8

print_section() { printf '\n== %s\n' "$1"; }

describe_modules() {
  local dir=$1 file desc
  for file in "$dir"/*.nix "$dir"/*/default.nix; do
    [ -f "$file" ] || continue
    [ "$(basename "$file")" = default.nix ] && [ "$(dirname "$file")" = "$dir" ] && continue
    desc=$(grep -m1 -oP 'enable = mkEnableOption "\K[^"]+' "$file" || true)
    printf '  %-48s %s\n' "$file" "${desc:-(no enable option)}"
  done
}

print_section "Host"
echo "  $host"
[ -f "$host_dir/default.nix" ] && echo "  switchboard: $host_dir/default.nix" || echo "  switchboard: MISSING"
[ -f "$host_doc" ] && echo "  host doc:    $host_doc" || echo "  host doc:    MISSING"
echo "  other hosts: $(ls hosts | grep -vx "$host" | tr '\n' ' ')"

print_section "Switches on $host"
grep -nE '^\s*[a-zA-Z-]+(\.[a-zA-Z-]+)* = (true|false);|^\s*[a-zA-Z-]+ = \{' "$host_dir/default.nix" |
  grep -vE 'boot\.|networking\.' | sed 's/^/  /' || echo "  none found"

print_section "System modules"
describe_modules modules/nixos

print_section "Home-manager modules"
describe_modules modules/home-manager

if [ $# -gt 0 ]; then
  pattern=$(IFS='|'; echo "$*")
  print_section "Mentions of: $*"
  for area in modules hosts docs/hosts .ai/prds assets; do
    hits=$(grep -rilE "$pattern" "$area" 2>/dev/null | head -n "$max_hits" || true)
    [ -n "$hits" ] && printf '  %s:\n%s\n' "$area" "$(sed 's/^/    /' <<<"$hits")"
  done
  true
fi
