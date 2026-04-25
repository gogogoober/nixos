{
  config,
  lib,
  pkgs,
  ...
}:

with lib;
let
  cfg = config.modules.hyprland;

  # Two classes for the two lifecycle modes; v2 PoC ships ephemeral only
  ephemeralClass = "hypr-popup-ephemeral";

  # Default popup geometry; revisit after seeing wiremix in action
  popupWidth = 800;
  popupHeight = 500;

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

    exec ${ghostty} --class="${ephemeralClass}" -e "$cmd"
  '';

  # Sidecar: kill the ephemeral popup when active window moves elsewhere.
  # Uses the v1 activewindow event because its payload includes the class
  # directly, so no extra hyprctl query per event.
  hyprPopupWatcher = pkgs.writeShellScriptBin "hypr-popup-watcher" ''
    sock="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
    ${pkgs.socat}/bin/socat -U - "UNIX-CONNECT:$sock" | while IFS= read -r line; do
      case "$line" in
        activewindow\>\>*)
          data="''${line#activewindow>>}"
          class="''${data%%,*}"
          if [ "$class" != "${ephemeralClass}" ]; then
            ${hyprctl} dispatch killwindow "class:^(${ephemeralClass})$" >/dev/null 2>&1 || true
          fi
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
      windowrulev2 = [
        "float,        class:^(${ephemeralClass})$"
        "size ${toString popupWidth} ${toString popupHeight}, class:^(${ephemeralClass})$"
        "center,       class:^(${ephemeralClass})$"
        "noblur,       class:^(${ephemeralClass})$"
        "noshadow,     class:^(${ephemeralClass})$"
        "rounding 0,   class:^(${ephemeralClass})$"
      ];

      exec-once = [
        "hypr-popup-watcher"
      ];
    };
  };
}
