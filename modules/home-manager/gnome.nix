{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;
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

    # Typed and documented by the NixOS module that feeds it
    display = mkOption {
      type = types.nullOr (types.attrsOf types.anything);
      default = null;
      description = "Built-in panel written to monitors.xml, supplied by modules.gnome.display.";
    };
  };

  config = mkIf cfg.enable {
    # Owning this file makes display settings Nix-only; the Settings panel cannot save over it
    xdg.configFile."monitors.xml" = mkIf (cfg.display != null) {
      text = ''
        <monitors version="2">
          <configuration>
            <layoutmode>physical</layoutmode>
            <logicalmonitor>
              <x>0</x>
              <y>0</y>
              <scale>${toString cfg.display.scale}</scale>
              <primary>yes</primary>
              <monitor>
                <monitorspec>
                  <connector>${cfg.display.connector}</connector>
                  <vendor>${cfg.display.vendor}</vendor>
                  <product>${cfg.display.product}</product>
                  <serial>${cfg.display.serial}</serial>
                </monitorspec>
                <mode>
                  <width>${toString cfg.display.width}</width>
                  <height>${toString cfg.display.height}</height>
                  <rate>${cfg.display.rate}</rate>
                </mode>
              </monitor>
            </logicalmonitor>
          </configuration>
        </monitors>
      '';
    };

    gtk = {
      enable = true;
      iconTheme = {
        name = "Marwaita-Dark";
        package = pkgs.marwaita-icons;
      };
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
          "speech-panel@nixos"
          "power-draw@nixos"
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
      };

      "org/gnome/settings-daemon/plugins/power" = {
        ambient-enabled = false; # Light sensor kept raising the backlight unasked
        sleep-inactive-ac-type = "suspend";
        sleep-inactive-ac-timeout = 420;
        sleep-inactive-battery-type = "suspend";
        sleep-inactive-battery-timeout = 420;
      };

      "org/gnome/settings-daemon/plugins/media-keys" = {
        custom-keybindings = [
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/touchscreen-fix/"
        ];
      };

      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/touchscreen-fix" = {
        name = "Reset touchscreen";
        binding = "<Alt><Shift>t";
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
