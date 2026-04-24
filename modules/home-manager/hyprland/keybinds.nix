{
  config,
  lib,
  pkgs,
  ...
}:

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

  # Workspaces 1-9: $mod switches, $mod+SHIFT moves window
  workspaceBinds =
    builtins.concatMap
      (n: [
        "$mod,       ${toString n}, Switch to workspace ${toString n},       workspace, ${toString n}"
        "$mod SHIFT, ${toString n}, Move window to workspace ${toString n},  movetoworkspace, ${toString n}"
      ])
      [
        1
        2
        3
        4
        5
        6
        7
        8
        9
      ];
in
{
  config = mkIf cfg.enable {
    home.packages = [
      hyprClipboard
      hyprCheatsheet
      hyprLockSleep
    ];

    wayland.windowManager.hyprland.settings = {
      "$mod" = "SUPER";

      bindd = [
        "$mod,       T,      Open terminal,         exec, kitty"
        "$mod,       B,      Open browser,          exec, firefox"
        "$mod,       A,      Open Claude,           exec, kitty -e claude"
        "$mod,       W,      Close window,          killactive,"
        "$mod,       F,      Toggle fullscreen,     fullscreen, 0"
        "$mod,       SPACE,  App launcher,          exec, hypr-app-drawer"
        "$mod,       K,      Show keybindings,      exec, hypr-cheatsheet"
        "$mod,       L,      Lock and sleep,        exec, hypr-lock-sleep"
        "$mod,       C,      Universal copy,        exec, hypr-clipboard copy"
        "$mod,       V,      Universal paste,       exec, hypr-clipboard paste"
        "$mod,       X,      Universal cut,         exec, hypr-clipboard cut"
        "SUPER,      escape, Speak selection,       exec, speak-selection"

        # Focus movement
        "$mod,       left,   Focus window left,     movefocus, l"
        "$mod,       right,  Focus window right,    movefocus, r"
        "$mod,       up,     Focus window up,       movefocus, u"
        "$mod,       down,   Focus window down,     movefocus, d"

        "$mod SHIFT, Q,      Exit Hyprland,         exit,"
      ]
      ++ workspaceBinds;
    };
  };
}
