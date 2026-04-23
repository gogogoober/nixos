# Home desktop configuration: GTK theming, cursor, app defaults
{ config, lib, pkgs, ... }:

with lib;
let cfg = config.modules.desktop;
in {
  options.modules.desktop = {
    enable = mkEnableOption "home desktop configuration";
  };

  config = mkIf cfg.enable {
    gtk = {
      enable = true;
      theme = {
        name = "adw-gtk3-dark";
        package = pkgs.adw-gtk3;
      };
      iconTheme = {
        name = "Papirus-Dark";
        package = pkgs.papirus-icon-theme;
      };
    };

    dconf.settings = {
      "org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
      };
    };

    home.packages = with pkgs; [
      firefox
      nautilus
      loupe       # image viewer
      papers      # pdf viewer
    ];
  };
}
