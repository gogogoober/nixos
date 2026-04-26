#!/usr/bin/env bash
# Spawned by waybar on-click via `hypr-popup <name>`.
#
# host.nix prepends a prelude that sets PATH and these variables:
#   CLASS_PREFIX, DISMISS_LOCK, DISMISS_GUARD_MS
# host.nix replaces the POPUP_META_CASE marker below with id-to-metadata
# branches generated from modules.hyprland.popups.

# shellcheck disable=SC2154
set -eu

name="${1:-}"
if [ -z "$name" ]; then
  echo "hypr-popup: missing popup name" >&2
  exit 1
fi

cmd=""
persistent=0
refresh_sig=0
case "$name" in
  # @POPUP_META_CASE@
  *) echo "hypr-popup: unknown name '$name'" >&2; exit 1 ;;
esac

target_class="$CLASS_PREFIX.$name"
target_workspace="popup-$name"

# If the click handler just dismissed this popup, do not respawn it from
# the same user click reaching waybar's on-click.
if [ -f "$DISMISS_LOCK" ]; then
  locked_class=$(sed -n '1p' "$DISMISS_LOCK" 2>/dev/null)
  ts=$(sed -n '2p' "$DISMISS_LOCK" 2>/dev/null || echo 0)
  now=$(date +%s%N)
  if [ "$((now - ts))" -lt "$((DISMISS_GUARD_MS * 1000000))" ] \
      && [ "$locked_class" = "$target_class" ]; then
    rm -f "$DISMISS_LOCK"
    exit 0
  fi
  rm -f "$DISMISS_LOCK"
fi

active_special=$(hyprctl monitors -j | jq -r '.[].specialWorkspace.name' | head -1)
clients_json=$(hyprctl clients -j)

# Dismiss any popup currently visible. Persistent popups are visible only
# when their special workspace is the active overlay; ephemerals are
# visible whenever their client exists.
visible_classes=$(printf '%s' "$clients_json" \
  | jq -r --arg p "$CLASS_PREFIX" '.[] | select(.class | startswith($p + ".")) | .class' \
  | sort -u)

target_was_visible=0
for c in $visible_classes; do
  c_id="${c#"$CLASS_PREFIX".}"
  c_persistent=0
  case "$c_id" in
    # @PERSISTENT_CASE@
  esac

  if [ "$c_persistent" = 0 ]; then
    hyprctl dispatch killwindow "class:^($c)$" >/dev/null 2>&1 || true
    [ "$c" = "$target_class" ] && target_was_visible=1
  else
    c_workspace="popup-$c_id"
    case "$active_special" in
      *"$c_workspace")
        hyprctl dispatch togglespecialworkspace "$c_workspace"
        [ "$c" = "$target_class" ] && target_was_visible=1
        ;;
    esac
  fi
done

# Toggle-off: clicking the same bar icon while its popup is visible just
# dismisses, without respawning a fresh one.
if [ "$target_was_visible" = 1 ]; then
  exit 0
fi

if [ "$persistent" = 1 ]; then
  # Process may already be running but hidden; reuse it instead of
  # spawning a duplicate (this is how spotify-player keeps its queue).
  existing=$(printf '%s' "$clients_json" \
    | jq --arg c "$target_class" '.[] | select(.class == $c)')
  if [ -n "$existing" ]; then
    hyprctl dispatch togglespecialworkspace "$target_workspace"
  else
    ghostty --class="$target_class" -e sh -c "$cmd" &
    disown
    # Let the window register before toggling its workspace.
    sleep 0.4
    hyprctl dispatch togglespecialworkspace "$target_workspace"
  fi
  exit 0
fi

ghostty --class="$target_class" -e sh -c "$cmd"

if [ "$refresh_sig" -gt 0 ]; then
  pkill --signal "RTMIN+$refresh_sig" waybar 2>/dev/null || true
fi
