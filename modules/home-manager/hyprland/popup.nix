{
  config,
  lib,
  pkgs,
  ...
}:

with lib;
let
  cfg = config.modules.hyprland;

  # GTK requires reverse-DNS app IDs; ghostty rejects anything else and falls
  # back to its default class, which would skip our windowrules and tile.
  ephemeralClass  = "dev.hypr-popup.ephemeral";
  persistentClass = "dev.hypr-popup.persistent";

  # Persistent popups live in a special workspace so togglespecialworkspace
  # hides them without killing the process. v2 has one persistent app (music);
  # additional persistent apps can share this class until per-app sizing or
  # placement diverges.
  persistentSpecialWs = "popup";

  # Default popup geometry and offsets from the top-right corner.
  # topOffset clears the 28px bar plus a small gap.
  popupWidth = 800;
  popupHeight = 500;
  rightOffset = 20;
  topOffset = 40;

  # Clicks at y < barReservedY are bar clicks; the handler skips them so
  # waybar's on-click owns the toggle without racing with our dispatch.
  # Mirrors barHeight (28) + barMargin (3) from bar.nix with a 1px buffer.
  barReservedY = 32;

  # Lock records which class the click handler just dismissed, so the bar
  # icon's on-click that fired the dismiss does not also respawn it. The lock
  # carries the class so a click that kills volume does not block opening
  # music.
  dismissLock = "/tmp/hypr-popup-dismissed-\$USER";
  dismissGuardMs = 300;

  hyprctl = "${pkgs.hyprland}/bin/hyprctl";
  jq = "${pkgs.jq}/bin/jq";
  ghostty = "${pkgs.ghostty}/bin/ghostty";

  hyprPopup = pkgs.writeShellScriptBin "hypr-popup" ''
    name="$1"

    case "$name" in
      music)                target_class="${persistentClass}" ;;
      volume|wifi|bluetooth) target_class="${ephemeralClass}" ;;
      *) echo "hypr-popup: unknown name '$name'" >&2; exit 1 ;;
    esac

    # If the click handler just dismissed this same class, do not respawn.
    lockfile="${dismissLock}"
    if [ -f "$lockfile" ]; then
      locked_class=$(sed -n '1p' "$lockfile" 2>/dev/null)
      ts=$(sed -n '2p' "$lockfile" 2>/dev/null || echo 0)
      now=$(date +%s%N)
      if [ "$((now - ts))" -lt "$((${toString dismissGuardMs} * 1000000))" ] \
          && [ "$locked_class" = "$target_class" ]; then
        rm -f "$lockfile"
        exit 0
      fi
      rm -f "$lockfile"
    fi

    # Persistent popup: spawn into a special workspace once, then toggle
    # visibility on subsequent clicks. Process keeps running when hidden.
    if [ "$name" = music ]; then
      existing=$(${hyprctl} clients -j \
        | ${jq} --arg c "${persistentClass}" '.[] | select(.class == $c)')
      if [ -n "$existing" ]; then
        ${hyprctl} dispatch togglespecialworkspace "${persistentSpecialWs}"
      else
        ${ghostty} --class="${persistentClass}" -e ${pkgs.spotify-player}/bin/spotify_player &
        disown
        # let the window register so togglespecialworkspace has a target
        sleep 0.4
        ${hyprctl} dispatch togglespecialworkspace "${persistentSpecialWs}"
      fi
      exit 0
    fi

    case "$name" in
      volume)    cmd="${pkgs.wiremix}/bin/wiremix";   refresh_sig=8  ;;
      wifi)      cmd="${pkgs.wifitui}/bin/wifitui";   refresh_sig=9  ;;
      bluetooth) cmd="${pkgs.bluetui}/bin/bluetui";   refresh_sig=10 ;;
    esac

    ${ghostty} --class="${ephemeralClass}" -e "$cmd"

    # Nudge the bar so the relevant module refreshes immediately on dismiss
    ${pkgs.procps}/bin/pkill --signal "RTMIN+$refresh_sig" waybar 2>/dev/null || true
  '';

  # bindn fires on every left-click and lets the click pass through to the
  # underlying app. Ephemeral popups are killed when cursor falls outside;
  # persistent popups are hidden via togglespecialworkspace so the process
  # keeps running. Either way, in-popup clicks pass through untouched.
  hyprPopupClickHandler = pkgs.writeShellScriptBin "hypr-popup-click-handler" ''
    cursor=$(${hyprctl} cursorpos)
    cx=$(printf '%s' "$cursor" | cut -d, -f1 | tr -d ' ')
    cy=$(printf '%s' "$cursor" | cut -d, -f2 | tr -d ' ')

    # Bar clicks are owned by waybar's on-click; skipping here avoids racing
    # the on-click that just toggled the special workspace.
    [ "$cy" -lt ${toString barReservedY} ] && exit 0

    inside() {
      ax=$(printf '%s' "$1" | ${jq} '.at[0]')
      ay=$(printf '%s' "$1" | ${jq} '.at[1]')
      pw=$(printf '%s' "$1" | ${jq} '.size[0]')
      ph=$(printf '%s' "$1" | ${jq} '.size[1]')
      [ "$cx" -ge "$ax" ] && [ "$cx" -lt "$((ax + pw))" ] \
        && [ "$cy" -ge "$ay" ] && [ "$cy" -lt "$((ay + ph))" ]
    }

    write_lock() {
      printf '%s\n%s\n' "$1" "$(date +%s%N)" > "${dismissLock}"
    }

    # Ephemeral first — only one popup visible at a time, so the moment we
    # find one and act we are done.
    ephemeral=$(${hyprctl} clients -j \
      | ${jq} --arg c "${ephemeralClass}" '.[] | select(.class == $c)')
    if [ -n "$ephemeral" ]; then
      inside "$ephemeral" && exit 0
      ${hyprctl} dispatch killwindow "class:^(${ephemeralClass})$" >/dev/null 2>&1 || true
      write_lock "${ephemeralClass}"
      exit 0
    fi

    # Persistent: act only if its special workspace is currently shown.
    persistent=$(${hyprctl} clients -j \
      | ${jq} --arg c "${persistentClass}" '.[] | select(.class == $c)')
    [ -z "$persistent" ] && exit 0

    active_special=$(${hyprctl} monitors -j \
      | ${jq} -r '.[].specialWorkspace.name' | head -1)
    case "$active_special" in
      *${persistentSpecialWs})
        inside "$persistent" && exit 0
        ${hyprctl} dispatch togglespecialworkspace "${persistentSpecialWs}"
        write_lock "${persistentClass}"
        ;;
    esac
  '';

  # Sidecar: workspace switches dismiss only ephemeral popups. Persistent
  # popups already hide automatically when their special workspace is no
  # longer the active overlay, so no action is needed for them here.
  reconnectDelaySec = 1;

  hyprPopupWatcher = pkgs.writeShellScriptBin "hypr-popup-watcher" ''
    sock="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
    while true; do
      ${pkgs.socat}/bin/socat -U - "UNIX-CONNECT:$sock" 2>/dev/null | while IFS= read -r line; do
        case "$line" in
          workspace\>\>*|workspacev2\>\>*)
            ${hyprctl} dispatch killwindow "class:^(${ephemeralClass})$" >/dev/null 2>&1 || true
            ;;
        esac
      done
      sleep ${toString reconnectDelaySec}
    done
  '';
in
{
  config = mkIf cfg.enable {
    home.packages = [
      hyprPopup
      hyprPopupClickHandler
      hyprPopupWatcher
      pkgs.wiremix
      pkgs.wifitui
      pkgs.bluetui
      pkgs.spotify-player
      pkgs.socat
    ];

    wayland.windowManager.hyprland.settings = {
      windowrule = [
        # Ephemeral popups
        "float on,                                                                       match:class ^(${ephemeralClass})$"
        "size ${toString popupWidth} ${toString popupHeight},                            match:class ^(${ephemeralClass})$"
        "move (monitor_w-window_w-${toString rightOffset}) ${toString topOffset},        match:class ^(${ephemeralClass})$"
        "no_blur on,                                                                     match:class ^(${ephemeralClass})$"
        "no_shadow on,                                                                   match:class ^(${ephemeralClass})$"
        "no_anim on,                                                                     match:class ^(${ephemeralClass})$"
        "rounding 0,                                                                     match:class ^(${ephemeralClass})$"

        # Persistent popups: same chrome, plus assigned to a special workspace
        # so togglespecialworkspace can hide/show without killing the process.
        "float on,                                                                       match:class ^(${persistentClass})$"
        "size ${toString popupWidth} ${toString popupHeight},                            match:class ^(${persistentClass})$"
        "move (monitor_w-window_w-${toString rightOffset}) ${toString topOffset},        match:class ^(${persistentClass})$"
        "no_blur on,                                                                     match:class ^(${persistentClass})$"
        "no_shadow on,                                                                   match:class ^(${persistentClass})$"
        "no_anim on,                                                                     match:class ^(${persistentClass})$"
        "rounding 0,                                                                     match:class ^(${persistentClass})$"
        "workspace special:${persistentSpecialWs} silent,                                match:class ^(${persistentClass})$"
      ];

      bindn = [
        ", mouse:272, exec, hypr-popup-click-handler"
      ];

      exec-once = [
        "hypr-popup-watcher"
      ];
    };
  };
}
