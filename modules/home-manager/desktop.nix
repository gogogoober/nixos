# Home desktop configuration: GTK dark mode, cursor, GNOME Forge dconf, Firefox default
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
    };

    home.pointerCursor = {
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
      size = 24;
      gtk.enable = true;
    };

    # Firefox as default browser
    xdg.mimeApps = {
      enable = true;
      defaultApplications = {
        "text/html" = "firefox.desktop";
        "x-scheme-handler/http" = "firefox.desktop";
        "x-scheme-handler/https" = "firefox.desktop";
      };
    };

    dconf.settings = {
      "org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
      };

      "org/gnome/shell" = {
        enabled-extensions = [
          "forge@jmmaranan.com"
          "appindicatorsupport@rgcjonas.gmail.com"
        ];
      };

      # Forge auto-tiling defaults
      # Additional Forge keybindings can be added to this dconf block later
      "org/gnome/shell/extensions/forge" = {
        tiling-mode-enabled = true;
        stacked-tiling-mode-enabled = true;
      };
    };
  };
}
