{
  config,
  lib,
  pkgs,
  ...
}:

with lib;
let
  cfg = config.modules.gnome;
in
{
  options.modules.gnome = {
    enable = mkEnableOption "GNOME desktop environment";
  };

  config = mkIf cfg.enable {
    services.desktopManager.gnome.enable = true;

    environment.gnome.excludePackages = with pkgs; [
      gnome-tour # Welcome/onboarding
      epiphany # GNOME Web browser
      gnome-music # Music player
      gnome-maps # Maps
      gnome-weather # Weather
      totem # Video player
    ];

    environment.systemPackages = with pkgs; [
      gnome-tweaks # GUI for GNOME tweaks
      dconf-editor # Low-level dconf editor
      gnomeExtensions.forge # Tiling window manager extension
      gnomeExtensions.appindicator # Legacy tray icon support
    ];

    services.udev.packages = [ pkgs.gnome-settings-daemon ];
  };
}
