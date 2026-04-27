{ config, lib, ... }:

let
  inherit (lib) mkIf;
  cfg = config.modules.hyprland;
in
{
  config = mkIf cfg.enable {
    wayland.windowManager.hyprland.settings = {
      # Any output, preferred res, auto position, 1x scale
      monitor = [ ",preferred,auto,1" ];

      # Wayland defaults for Electron, Firefox, Qt
      env = [
        "NIXOS_OZONE_WL,1"
        "MOZ_ENABLE_WAYLAND,1"
        "QT_QPA_PLATFORM,wayland;xcb"
        "XDG_SESSION_TYPE,wayland"
      ];

      exec-once = [
        "mako" # Notification daemon
        "waybar" # Top bar
      ];
    };
  };
}
