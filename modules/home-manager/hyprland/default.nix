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
    ./popup.nix # v2 reusable floating-terminal popup host
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
