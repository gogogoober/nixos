# Hyprland user config: keybinds, cheatsheet, lock-sleep, universal clipboard.
# Minimum-viable daily-driver session — monitor fallback, workspace keybinds,
# window focus navigation, notification daemon autostart. Build out further
# (waybar, hypridle, hyprlock, hyprsunset, theming) once the session proves out.
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.modules.hyprland;

  hyprClipboard = pkgs.writeShellScriptBin "hypr-clipboard" ''
    action="$1"
    class=$(${pkgs.hyprland}/bin/hyprctl activewindow -j | ${pkgs.jq}/bin/jq -r .class)
    case "$class" in
      kitty|Alacritty|foot|org.wezfurlong.wezterm) mod="CTRL SHIFT" ;;
      *) mod="CTRL" ;;
    esac
    case "$action" in
      copy)  key=c ;;
      paste) key=v ;;
      cut)   key=x ;;
    esac
    ${pkgs.hyprland}/bin/hyprctl dispatch sendshortcut "$mod, $key, activewindow"
  '';

  hyprCheatsheet = pkgs.writeShellScriptBin "hypr-cheatsheet" ''
    ${pkgs.hyprland}/bin/hyprctl binds -j \
      | ${pkgs.jq}/bin/jq -r '.[] | select(.description != "") | "\(.key)\t\(.description)"' \
      | ${pkgs.wofi}/bin/wofi --dmenu --prompt="Keybindings" --width=500 --height=600
  '';

  hyprLockSleep = pkgs.writeShellScriptBin "hypr-lock-sleep" ''
    ${pkgs.hyprlock}/bin/hyprlock --immediate &
    sleep 0.3
    ${pkgs.systemd}/bin/systemctl suspend
  '';

  # Workspace 1-9: switch with $mod, move window with $mod+SHIFT.
  workspaceBinds = builtins.concatMap (n: [
    "$mod,       ${toString n}, Switch to workspace ${toString n},       workspace, ${toString n}"
    "$mod SHIFT, ${toString n}, Move window to workspace ${toString n},  movetoworkspace, ${toString n}"
  ]) [ 1 2 3 4 5 6 7 8 9 ];
in {
  options.modules.hyprland = {
    enable = mkEnableOption "Hyprland home-manager config";
  };

  config = mkIf cfg.enable {
    home.packages = [ hyprClipboard hyprCheatsheet hyprLockSleep ];

    wayland.windowManager.hyprland = {
      enable = true;
      # NixOS module (modules/nixos/hyprland.nix) installs Hyprland system-wide
      # from the flake input. Suppress home-manager's user-level install to avoid
      # a duplicate Hyprland package and session-file confusion.
      package = null;
      portalPackage = null;

      settings = {
        "$mod" = "SUPER";

        # Catch-all: any output, preferred resolution, auto position, auto scale.
        monitor = [ ",preferred,auto,auto" ];

        # Wayland-friendly defaults for Electron + Firefox + Qt.
        env = [
          "NIXOS_OZONE_WL,1"
          "MOZ_ENABLE_WAYLAND,1"
          "QT_QPA_PLATFORM,wayland;xcb"
          "XDG_SESSION_TYPE,wayland"
        ];

        exec-once = [
          "mako"                                   # notification daemon
          "wl-paste --watch cliphist store"        # optional clipboard history, harmless if cliphist missing
        ];

        bindd = [
          "$mod,       T,      Open terminal,         exec, kitty"
          "$mod,       B,      Open browser,          exec, firefox"
          "$mod,       A,      Open Claude,           exec, kitty -e claude"
          "$mod,       W,      Close window,          killactive,"
          "$mod,       F,      Toggle fullscreen,     fullscreen, 0"
          "$mod,       SPACE,  App launcher,          exec, wofi --show drun"
          "$mod,       K,      Show keybindings,      exec, hypr-cheatsheet"
          "$mod,       L,      Lock and sleep,        exec, hypr-lock-sleep"
          "$mod,       C,      Universal copy,        exec, hypr-clipboard copy"
          "$mod,       V,      Universal paste,       exec, hypr-clipboard paste"
          "$mod,       X,      Universal cut,         exec, hypr-clipboard cut"
          "ALT,        period, Speak selection,       exec, speak-selection"

          # Focus movement
          "$mod,       left,   Focus window left,     movefocus, l"
          "$mod,       right,  Focus window right,    movefocus, r"
          "$mod,       up,     Focus window up,       movefocus, u"
          "$mod,       down,   Focus window down,     movefocus, d"

          # Escape hatch — log out of Hyprland back to GDM.
          "$mod SHIFT, Q,      Exit Hyprland,         exit,"
        ] ++ workspaceBinds;
      };
    };
  };
}
