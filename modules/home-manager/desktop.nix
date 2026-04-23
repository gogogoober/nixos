# Home desktop configuration: GTK dark mode, cursor, GNOME Forge dconf, Firefox default
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.modules.desktop;

  wallpaperDir = ../../home/hugo/assets/wallpapers;

  wallpaperCycle = pkgs.writeShellScript "wallpaper-cycle" ''
    set -eu
    export PATH=${pkgs.glib}/bin:${pkgs.coreutils}/bin:${pkgs.findutils}/bin:$PATH
    DIR="${wallpaperDir}"
    FILE=$(find "$DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | shuf -n 1)
    if [ -n "$FILE" ]; then
      gsettings set org.gnome.desktop.background picture-uri "file://$FILE"
      gsettings set org.gnome.desktop.background picture-uri-dark "file://$FILE"
      gsettings set org.gnome.desktop.background picture-options "zoom"
    fi
  '';
in {
  options.modules.desktop = {
    enable = mkEnableOption "home desktop configuration";
  };

  config = mkIf cfg.enable {
    gtk = {
      enable = true;
      iconTheme = {
        name = "Marwaita-Dark";
        package = pkgs.marwaita-icons;
      };
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
        icon-theme = "Marwaita-Dark";
      };

      "org/gnome/desktop/sound" = {
        event-sounds = false;
        input-feedback-sounds = false;
        theme-name = "__custom";
      };

      "org/gnome/desktop/wm/preferences" = {
        audible-bell = false;
      };

      "org/gnome/desktop/a11y" = {
        always-show-universal-access-status = false;
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

      # Free up Alt+Esc (default: cycle-windows) for TTS.
      "org/gnome/desktop/wm/keybindings" = {
        cycle-windows = [ ];
        cycle-windows-backward = [ ];
      };

      "org/gnome/settings-daemon/plugins/media-keys" = {
        custom-keybindings = [
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/speak-selection/"
        ];
      };

      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/speak-selection" = {
        name = "Speak selection";
        binding = "<Alt>period";
        command = "speak-selection";
      };
    };

    systemd.user.services.wallpaper-cycle = {
      Unit.Description = "Cycle GNOME wallpaper from assets/wallpapers";
      Service = {
        Type = "oneshot";
        ExecStart = "${wallpaperCycle}";
      };
    };

    systemd.user.timers.wallpaper-cycle = {
      Unit.Description = "Cycle GNOME wallpaper every 5 minutes";
      Timer = {
        OnActiveSec = "10s";
        OnUnitActiveSec = "5min";
        Unit = "wallpaper-cycle.service";
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
