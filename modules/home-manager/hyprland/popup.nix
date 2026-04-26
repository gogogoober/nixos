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
  ephemeralClass = "dev.hypr-popup.ephemeral";

  # Default popup geometry and offsets from the top-right corner.
  # topOffset clears the 28px bar plus a small gap.
  popupWidth = 800;
  popupHeight = 500;
  rightOffset = 20;
  topOffset = 40;

  # Lockfile records when an outside-click just dismissed the popup, so a
  # bar-icon click that triggered the dismiss does not also respawn it.
  dismissLock = "/tmp/hypr-popup-dismissed-\$USER";
  dismissGuardMs = 300;

  hyprctl = "${pkgs.hyprland}/bin/hyprctl";
  jq = "${pkgs.jq}/bin/jq";
  ghostty = "${pkgs.ghostty}/bin/ghostty";

  # blugo is not in nixpkgs; build from source with the project's pinned go
  blugo = pkgs.callPackage ../../../packages/blugo.nix {
    buildGoModule = pkgs.buildGoModule.override { go = pkgs.go_1_25; };
  };

  hyprPopup = pkgs.writeShellScriptBin "hypr-popup" ''
    name="$1"

    # If the click handler just dismissed the popup, do not respawn it.
    lockfile="${dismissLock}"
    if [ -f "$lockfile" ]; then
      ts=$(cat "$lockfile" 2>/dev/null || echo 0)
      now=$(date +%s%N)
      if [ "$((now - ts))" -lt "$((${toString dismissGuardMs} * 1000000))" ]; then
        rm -f "$lockfile"
        exit 0
      fi
      rm -f "$lockfile"
    fi

    case "$name" in
      volume)    cmd="${pkgs.wiremix}/bin/wiremix";   refresh_sig=8  ;;
      wifi)      cmd="${pkgs.wifitui}/bin/wifitui";   refresh_sig=9  ;;
      bluetooth) cmd="${blugo}/bin/blugo";            refresh_sig=10 ;;
      *)         echo "hypr-popup: unknown name '$name'" >&2; exit 1 ;;
    esac

    ${ghostty} --class="${ephemeralClass}" -e "$cmd"

    # Nudge the bar so the relevant module refreshes immediately on dismiss
    ${pkgs.procps}/bin/pkill --signal "RTMIN+$refresh_sig" waybar 2>/dev/null || true
  '';

  # bindn fires on every left-click and lets the click pass through to the
  # underlying app. This handler dismisses the popup only when the cursor is
  # outside its bounds, leaving in-popup clicks alone for wiremix to handle.
  hyprPopupClickHandler = pkgs.writeShellScriptBin "hypr-popup-click-handler" ''
    popup=$(${hyprctl} clients -j \
      | ${jq} --arg c "${ephemeralClass}" '.[] | select(.class == $c)')
    [ -z "$popup" ] && exit 0

    ax=$(printf '%s' "$popup" | ${jq} '.at[0]')
    ay=$(printf '%s' "$popup" | ${jq} '.at[1]')
    w=$(printf '%s' "$popup" | ${jq} '.size[0]')
    h=$(printf '%s' "$popup" | ${jq} '.size[1]')

    cursor=$(${hyprctl} cursorpos)
    cx=$(printf '%s' "$cursor" | cut -d, -f1 | tr -d ' ')
    cy=$(printf '%s' "$cursor" | cut -d, -f2 | tr -d ' ')

    if [ "$cx" -ge "$ax" ] && [ "$cx" -lt "$((ax + w))" ] \
        && [ "$cy" -ge "$ay" ] && [ "$cy" -lt "$((ay + h))" ]; then
      exit 0
    fi

    ${hyprctl} dispatch killwindow "class:^(${ephemeralClass})$" >/dev/null 2>&1 || true
    date +%s%N > "${dismissLock}"
  '';

  # Sidecar: workspace switches still need to dismiss the popup. Click-outside
  # is handled by the bindn handler above, not here.
  # Reconnect on every socat exit. The compositor tears the script down when
  # the session ends, so the loop has no own termination condition.
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
      blugo
      pkgs.socat
    ];

    wayland.windowManager.hyprland.settings = {
      windowrule = [
        "float on,                                                                       match:class ^(${ephemeralClass})$"
        "size ${toString popupWidth} ${toString popupHeight},                            match:class ^(${ephemeralClass})$"
        "move (monitor_w-window_w-${toString rightOffset}) ${toString topOffset},        match:class ^(${ephemeralClass})$"
        "no_blur on,                                                                     match:class ^(${ephemeralClass})$"
        "no_shadow on,                                                                   match:class ^(${ephemeralClass})$"
        "no_anim on,                                                                     match:class ^(${ephemeralClass})$"
        "rounding 0,                                                                     match:class ^(${ephemeralClass})$"
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
