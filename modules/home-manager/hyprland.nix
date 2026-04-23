# Hyprland user config: keybinds, cheatsheet, lock-sleep, universal clipboard
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
in {
  options.modules.hyprland = {
    enable = mkEnableOption "Hyprland home-manager config";
  };

  config = mkIf cfg.enable {
    home.packages = [ hyprClipboard hyprCheatsheet hyprLockSleep ];

    wayland.windowManager.hyprland = {
      enable = true;
      settings = {
        "$mod" = "SUPER";

        bindd = [
          "$mod,       T,     Open terminal,        exec, kitty"
          "$mod,       B,     Open browser,         exec, firefox"
          "$mod,       W,     Close window,         killactive,"
          "$mod,       F,     Toggle fullscreen,    fullscreen, 0"
          "$mod,       SPACE, App launcher,         exec, wofi --show drun"
          "$mod,       K,     Show keybindings,     exec, hypr-cheatsheet"
          "$mod,       L,     Lock and sleep,       exec, hypr-lock-sleep"
          "$mod,       C,     Universal copy,       exec, hypr-clipboard copy"
          "$mod,       V,     Universal paste,      exec, hypr-clipboard paste"
          "$mod,       X,     Universal cut,        exec, hypr-clipboard cut"
          "$mod,       period, Speak selection,      exec, speak-selection"
        ];
      };
    };
  };
}
