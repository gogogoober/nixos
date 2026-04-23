# GNOME desktop environment: GDM, GNOME shell, exclude bloat
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
    environment.gnome.excludePackages = with pkgs; [
      epiphany        # web browser
      geary           # email
      gnome-music
      gnome-tour
      gnome-contacts
      gnome-maps
      gnome-weather
      totem           # video player
      yelp            # help viewer
      simple-scan
    ];

    # Useful GNOME extras
    environment.systemPackages = with pkgs; [
      gnome-tweaks
      gnome-extension-manager
    ];
  };
}
