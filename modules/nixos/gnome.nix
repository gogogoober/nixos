# GNOME desktop environment: GNOME shell, Forge tiling, AppIndicator.
# GDM + xserver live in desktop.nix so they stay up regardless of DE choice.
{ config, lib, pkgs, ... }:

with lib;
let cfg = config.modules.gnome;
in {
  options.modules.gnome = {
    enable = mkEnableOption "GNOME desktop environment";
  };

  config = mkIf cfg.enable {
    services.desktopManager.gnome.enable = true;

    # Remove GNOME bloat
    environment.gnome.excludePackages = with pkgs; [
      gnome-tour
      epiphany
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
