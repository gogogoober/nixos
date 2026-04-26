{ config, lib, ... }:

with lib;
let
  cfg = config.modules.hyprland;
in
{
  imports = [
    ./startup.nix # monitor, env vars, exec-once autostart
    ./keybinds.nix # $mod binds + helper scripts
    ./tiling.nix # gaps, borders, layout engine, fullscreen rules
    ./windows.nix # per-window aesthetic: rounding, blur, shadow
    ./gestures.nix # touchpad gestures
    ./bar.nix # waybar config + styling
    ./overlay.nix # app drawer + power menu (shared popover UI/UX)
    ./quick-settings.nix # v1 wofi quick settings (wifi/bluetooth/power)
    ./quick-popups/host.nix # reusable floating-terminal popup host
    ./quick-popups/music.nix
    ./quick-popups/volume.nix
    ./quick-popups/wifi.nix
    ./quick-popups/bluetooth.nix
    ./notifications.nix # mako notification daemon config
  ];

  options.modules.hyprland = {
    enable = mkEnableOption "Hyprland home-manager config";
  };

  config = mkIf cfg.enable {
    wayland.windowManager.hyprland = {
      enable = true;
      # NixOS installs Hyprland system-wide; suppress the home-manager copy
      package = null;
      portalPackage = null;
    };
  };
}
