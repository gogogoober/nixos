# Full-screen-ish popover overlays that share a common UI/UX: the app drawer
# (launch an app) and the power menu (lock/suspend/reboot/shutdown). Both are
# currently wofi --dmenu popups — intentionally colocated so the styling and
# interaction model stay in lockstep as this gets redesigned.
#
# TODO: replace the wofi dmenu look with a unified custom overlay (rounded
# card, icon grid for the app drawer, iconed rows for the power menu).
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.modules.hyprland;

  # App drawer — wraps `wofi --show drun` so the keybind in keybinds.nix
  # just invokes `hypr-app-drawer` and all overlay styling lives here.
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
in {
  config = mkIf cfg.enable {
    home.packages = [ hyprAppDrawer hyprPowerMenu ];
  };
}
