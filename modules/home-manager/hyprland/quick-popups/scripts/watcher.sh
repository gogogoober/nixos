#!/usr/bin/env bash
# Dismisses visible ephemeral popups on workspace change (Hyprland IPC socket).
# host.nix prepends PATH, CLASS_PREFIX, RECONNECT_DELAY_SEC and fills
# the PERSISTENT_CASE marker.

# shellcheck disable=SC2154
set -u

sock="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

while true; do
  socat -U - "UNIX-CONNECT:$sock" 2>/dev/null | while IFS= read -r line; do
    case "$line" in
      workspace\>\>*|workspacev2\>\>*)
        hyprctl clients -j \
          | jq -r --arg p "$CLASS_PREFIX" '.[] | select(.class | startswith($p + ".")) | .class' \
          | while IFS= read -r c; do
              c_id="${c#"$CLASS_PREFIX".}"
              c_persistent=0
              case "$c_id" in
                # @PERSISTENT_CASE@
              esac
              if [ "$c_persistent" = 0 ]; then
                hyprctl dispatch killwindow "class:^($c)$" >/dev/null 2>&1 || true
              fi
            done
        ;;
    esac
  done
  sleep "$RECONNECT_DELAY_SEC"
done
