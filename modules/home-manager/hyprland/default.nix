{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf mkDefault;
  cfg = config.modules.hyprland;
in
{
  imports = [
    ./startup.nix # monitor, env vars, exec-once autostart
    ./keybinds.nix # $mod binds + helper scripts
    ./tiling.nix # gaps, borders, layout engine, fullscreen rules
    ./windows.nix # per-window aesthetic: rounding, blur, shadow
    ./gestures.nix # touchpad gestures
    ./input.nix # mouse + touchpad device settings
    ./bar.nix # waybar config + styling
    ./wofi.nix # wofi config + design-system styling
    ./quick-settings.nix # v1 wofi quick settings (wifi/bluetooth/power)
    ./quick-popups/host.nix # reusable floating-terminal popup host
    ./quick-popups/launcher.nix # fsel TUI app launcher
    ./quick-popups/music.nix
    ./quick-popups/volume.nix
    ./quick-popups/wifi.nix
    ./quick-popups/bluetooth.nix
    ./quick-popups/battery.nix
    ./notifications.nix # mako notification daemon config
    ./hypridle.nix # idle daemon: suspend-then-hibernate after 7 min
    ./wallpaper.nix # hyprpaper config + 5-minute cycler
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

    home.pointerCursor = {
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
      size = 24;
      gtk.enable = true;
    };

    modules.file-manager.enable = mkDefault true;
  };
}
