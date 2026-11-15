#!/usr/bin/env bash
# Usage: find-option.sh <keyword>   run from the repo root
# Searches the pinned nixpkgs and home-manager inputs, not the latest upstream.
set -euo pipefail

keyword=${1:?keyword required}
max_files=15
max_lines=25

input_path() {
  nix eval --raw --impure --expr "(builtins.getFlake (toString ./.)).inputs.$1.outPath" 2>/dev/null
}

search_tree() {
  local label=$1 root=$2
  printf '\n== %s (%s)\n' "$label" "$root"
  echo "  module files named like '$keyword':"
  find "$root" -iname "*$keyword*.nix" | sed "s|$root/||; s/^/    /" | head -n "$max_files"
  echo "  option declarations mentioning '$keyword':"
  rg -n --no-heading -i "(mkEnableOption|mkPackageOption|mkOption).*$keyword|$keyword[a-zA-Z]* = mk(Enable|Package)?Option" "$root" |
    sed "s|$root/||; s/^/    /" | head -n "$max_lines"
}

nixpkgs=$(input_path nixpkgs)
home_manager=$(input_path home-manager)

search_tree "NixOS options" "$nixpkgs/nixos/modules"
search_tree "home-manager options" "$home_manager/modules"
