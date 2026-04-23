# GNOME desktop environment: GDM, GNOME shell, Forge tiling, AppIndicator
{ config, lib, pkgs, ... }:

with lib;
let cfg = config.modules.gnome;
in {
  options.modules.gnome = {
    enable = mkEnableOption "GNOME desktop environment";
  };

  config = mkIf cfg.enable {
    services.xserver.enable = true;
    services.xserver.displayManager.gdm.enable = true;
    services.xserver.desktopManager.gnome.enable = true;

    # Remove GNOME bloat
    services.gnome.excludePackages = with pkgs; [
      gnome-tour
      epiphany
      geary
      gnome-music
      gnome-maps
      gnome-weather
      totem
    ];

    # Tweaks, dconf editor, and shell extensions
    environment.systemPackages = with pkgs; [
      gnome-tweaks
      dconf-editor
      gnomeExtensions.forge
      gnomeExtensions.appindicator
    ];

    # AppIndicator tray icon support
    services.udev.packages = [ pkgs.gnome-settings-daemon ];
  };
}
