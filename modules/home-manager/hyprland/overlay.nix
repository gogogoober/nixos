{
  config,
  lib,
  pkgs,
  ...
}:

with lib;
let
  cfg = config.modules.hyprland;

  hyprAppDrawer = pkgs.writeShellScriptBin "hypr-app-drawer" ''
    exec wofi --show drun
  '';

  hyprPowerMenu = pkgs.writeShellScriptBin "hypr-power-menu" ''
    choice=$(printf 'Lock\nSuspend\nReboot\nShutdown' \
      | ${pkgs.wofi}/bin/wofi --dmenu --prompt="Power" --width=220 --height=200)
    case "$choice" in
      Lock)     ${pkgs.hyprlock}/bin/hyprlock ;;
      Suspend)  ${pkgs.systemd}/bin/systemctl suspend ;;
      Reboot)   ${pkgs.systemd}/bin/systemctl reboot ;;
      Shutdown) ${pkgs.systemd}/bin/systemctl poweroff ;;
    esac
  '';
in
{
  config = mkIf cfg.enable {
    home.packages = [
      hyprAppDrawer
      hyprPowerMenu
    ];
  };
}
