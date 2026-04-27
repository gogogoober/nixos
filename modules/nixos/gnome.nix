{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.gnome;
in
{
  options.modules.gnome = {
    enable = mkEnableOption "GNOME desktop environment";
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = config.modules.desktop.enable;
        message = "modules.gnome.enable requires modules.desktop.enable (xserver, GDM, and pipewire live there).";
      }
    ];

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

    home-manager.users.${config.modules.user.name}.modules.gnome.enable = true;
  };
}
