#!/usr/bin/env bash
# Bound to bindn left-click. Dismisses any visible popup when the click
# lands outside it, and lets the click pass through untouched.
#
# host.nix prepends a prelude that sets PATH and these variables:
#   CLASS_PREFIX, DISMISS_LOCK, BAR_RESERVED_Y
# host.nix replaces the PERSISTENT_CASE marker below with id-to-persistent
# branches generated from modules.hyprland.popups.

# shellcheck disable=SC2154
set -eu

cursor=$(hyprctl cursorpos)
cx=$(printf '%s' "$cursor" | cut -d, -f1 | tr -d ' ')
cy=$(printf '%s' "$cursor" | cut -d, -f2 | tr -d ' ')

# Bar clicks owned by waybar's on-click; skipping here avoids racing the
# on-click that already toggles the popup itself.
[ "$cy" -lt "$BAR_RESERVED_Y" ] && exit 0

inside() {
  ax=$(printf '%s' "$1" | jq '.at[0]')
  ay=$(printf '%s' "$1" | jq '.at[1]')
  pw=$(printf '%s' "$1" | jq '.size[0]')
  ph=$(printf '%s' "$1" | jq '.size[1]')
  [ "$cx" -ge "$ax" ] && [ "$cx" -lt "$((ax + pw))" ] \
    && [ "$cy" -ge "$ay" ] && [ "$cy" -lt "$((ay + ph))" ]
}

write_lock() {
  printf '%s\n%s\n' "$1" "$(date +%s%N)" > "$DISMISS_LOCK"
}

active_special=$(hyprctl monitors -j | jq -r '.[].specialWorkspace.name' | head -1)
clients_json=$(hyprctl clients -j)

visible_classes=$(printf '%s' "$clients_json" \
  | jq -r --arg p "$CLASS_PREFIX" '.[] | select(.class | startswith($p + ".")) | .class' \
  | sort -u)

for c in $visible_classes; do
  c_id="${c#"$CLASS_PREFIX".}"
  c_persistent=0
  case "$c_id" in
    # @PERSISTENT_CASE@
  esac

  client=$(printf '%s' "$clients_json" | jq --arg cl "$c" '.[] | select(.class == $cl)')
  [ -z "$client" ] && continue

  if [ "$c_persistent" = 0 ]; then
    inside "$client" && exit 0
    hyprctl dispatch killwindow "class:^($c)$" >/dev/null 2>&1 || true
    write_lock "$c"
    exit 0
  fi

  c_workspace="popup-$c_id"
  case "$active_special" in
    *"$c_workspace")
      inside "$client" && exit 0
      hyprctl dispatch togglespecialworkspace "$c_workspace"
      write_lock "$c"
      exit 0
      ;;
  esac
done
