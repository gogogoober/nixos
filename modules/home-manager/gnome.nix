{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.gnome;

  wallpaperDir = ../../assets/wallpapers;

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
in
{
  options.modules.gnome = {
    enable = mkEnableOption "GNOME home-manager configuration";
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

      "org/gnome/desktop/peripherals/touchpad" = {
        natural-scroll = true;
      };

      "org/gnome/desktop/peripherals/mouse" = {
        natural-scroll = true;
      };

      "org/gnome/shell" = {
        enabled-extensions = [
          "forge@jmmaranan.com"
          "appindicatorsupport@rgcjonas.gmail.com"
        ];
      };

      "org/gnome/mutter" = {
        experimental-features = [ "scale-monitor-framebuffer" ];
        # Super becomes a plain modifier, otherwise it eats Super+key chords
        overlay-key = "";
      };

      "org/gnome/shell/extensions/forge" = {
        tiling-mode-enabled = true;
        stacked-tiling-mode-enabled = true;
        focus-border-color = "rgba(180, 190, 254, 1)"; # design-system border.focus, lavender #b4befe
        split-border-color = "rgba(249, 226, 175, 1)"; # design-system status.warn, yellow #f9e2af
      };

      # Free Alt+Esc for TTS
      "org/gnome/desktop/wm/keybindings" = {
        cycle-windows = [ ];
        cycle-windows-backward = [ ];
      };

      # 7 min idle → suspend; sleep.conf hibernates 8 min later (15 min total)
      "org/gnome/settings-daemon/plugins/power" = {
        sleep-inactive-ac-type = "suspend";
        sleep-inactive-ac-timeout = 420;
        sleep-inactive-battery-type = "suspend";
        sleep-inactive-battery-timeout = 420;
      };

      "org/gnome/settings-daemon/plugins/media-keys" = {
        custom-keybindings = [
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/speak-selection/"
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/touchscreen-fix/"
        ];
      };

      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/speak-selection" = {
        name = "Speak selection";
        binding = "<Alt>Escape";
        command = "speak-selection";
      };

      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/touchscreen-fix" = {
        name = "Reset touchscreen";
        binding = "<Super><Shift>t";
        command = "touchscreen-fix";
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
