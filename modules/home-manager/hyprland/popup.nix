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

  hyprctl = "${pkgs.hyprland}/bin/hyprctl";
  jq = "${pkgs.jq}/bin/jq";
  ghostty = "${pkgs.ghostty}/bin/ghostty";

  # Spawn or toggle: bar layer-shell does not change activewindow on click,
  # so the sidecar cannot dismiss on bar clicks. The toggle check below is
  # what makes a second icon click dismiss instead of stack a new popup.
  hyprPopup = pkgs.writeShellScriptBin "hypr-popup" ''
    name="$1"

    if ${hyprctl} clients -j \
        | ${jq} -e --arg c "${ephemeralClass}" '.[] | select(.class == $c)' \
        >/dev/null 2>&1; then
      ${hyprctl} dispatch killwindow "class:^(${ephemeralClass})$" >/dev/null 2>&1 || true
      exit 0
    fi

    case "$name" in
      volume) cmd="${pkgs.wiremix}/bin/wiremix" ;;
      *)      echo "hypr-popup: unknown name '$name'" >&2; exit 1 ;;
    esac

    ${ghostty} --class="${ephemeralClass}" -e "$cmd"

    # Nudge the bar so volume (and any future setting) refreshes immediately
    ${pkgs.procps}/bin/pkill --signal RTMIN+8 waybar 2>/dev/null || true
  '';

  # Sidecar: kill the ephemeral popup on outside-click or workspace switch.
  # activewindow handles focus changes; workspace handles the case where the
  # user changes workspace without first changing focus to a window.
  hyprPopupWatcher = pkgs.writeShellScriptBin "hypr-popup-watcher" ''
    sock="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
    kill_popup() {
      ${hyprctl} dispatch killwindow "class:^(${ephemeralClass})$" >/dev/null 2>&1 || true
    }
    ${pkgs.socat}/bin/socat -U - "UNIX-CONNECT:$sock" | while IFS= read -r line; do
      case "$line" in
        activewindow\>\>*)
          data="''${line#activewindow>>}"
          class="''${data%%,*}"
          [ "$class" != "${ephemeralClass}" ] && kill_popup
          ;;
        workspace\>\>*|workspacev2\>\>*)
          kill_popup
          ;;
      esac
    done
  '';
in
{
  config = mkIf cfg.enable {
    home.packages = [
      hyprPopup
      hyprPopupWatcher
      pkgs.wiremix
      pkgs.socat
    ];

    wayland.windowManager.hyprland.settings = {
      windowrule = [
        "float on,                                                                       match:class ^(${ephemeralClass})$"
        "size ${toString popupWidth} ${toString popupHeight},                            match:class ^(${ephemeralClass})$"
        "move (monitor_w-window_w-${toString rightOffset}) ${toString topOffset},        match:class ^(${ephemeralClass})$"
        "no_blur on,                                                                     match:class ^(${ephemeralClass})$"
        "no_shadow on,                                                                   match:class ^(${ephemeralClass})$"
        "rounding 0,                                                                     match:class ^(${ephemeralClass})$"
      ];

      exec-once = [
        "hypr-popup-watcher"
      ];
    };
  };
}
