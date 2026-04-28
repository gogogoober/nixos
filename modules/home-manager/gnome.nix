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

  # Forge reads colors from this stylesheet, not from dconf — dconf keys are just prefs-UI state
  forgeFocusRgb = "203, 166, 247"; # design-system text.accent, mauve #cba6f7
  forgeSplitRgb = "249, 226, 175"; # design-system status.warn, yellow #f9e2af

  forgeStylesheet = ''
    .tiled {
      color: rgba(${forgeFocusRgb}, 1);
      opacity: 1;
      border-width: 3px;
    }

    .split {
      color: rgba(${forgeSplitRgb}, 1);
      opacity: 1;
      border-width: 3px;
    }

    .stacked {
      color: rgba(247, 162, 43, 1);
      opacity: 1;
      border-width: 3px;
    }

    .tabbed {
      color: rgba(17, 199, 224, 1);
      opacity: 1;
      border-width: 3px;
    }

    .floated {
      color: rgba(180, 167, 214, 1);
      border-width: 3px;
      opacity: 1;
    }

    .window-tiled-border {
      border-width: 3px;
      border-color: rgba(${forgeFocusRgb}, 1);
      border-style: solid;
      border-radius: 14px;
    }

    .window-split-border {
      border-width: 3px;
      border-color: rgba(${forgeSplitRgb}, 1);
      border-style: solid;
      border-radius: 14px;
    }

    .window-split-horizontal {
      border-left-width: 0;
      border-top-width: 0;
      border-bottom-width: 0;
    }

    .window-split-vertical {
      border-left-width: 0;
      border-top-width: 0;
      border-right-width: 0;
    }

    .window-stacked-border {
      border-width: 3px;
      border-color: rgba(247, 162, 43, 1);
      border-style: solid;
      border-radius: 14px;
    }

    .window-tabbed-border {
      border-width: 3px;
      border-color: rgba(17, 199, 224, 1);
      border-style: solid;
      border-radius: 14px;
    }

    .window-tabbed-bg {
      border-radius: 8px;
    }

    .window-tabbed-tab {
      background-color: rgba(54, 47, 45, 1);
      border-color: rgba(17, 199, 224, 0.6);
      border-width: 1px;
      border-radius: 8px;
      color: white;
      margin: 1px;
      box-shadow: 0 0 0 1px rgba(0, 0, 0, 0.2);
    }

    .window-tabbed-tab-active {
      background-color: rgba(17, 199, 224, 1);
      color: black;
      box-shadow: 0 0 0 1px rgba(0, 0, 0, 0.2);
    }

    .window-tabbed-tab-close {
      padding: 3px;
      margin: 4px;
      border-radius: 16px;
      width: 16px;
      background-color: #e06666;
    }

    .window-tabbed-tab-icon {
      margin: 3px;
    }

    .window-floated-border {
      border-width: 3px;
      border-color: rgba(180, 167, 214, 1);
      border-style: solid;
      border-radius: 14px;
    }

    .window-tilepreview-tiled {
      border-width: 1px;
      border-color: rgba(${forgeFocusRgb}, 0.4);
      border-style: solid;
      border-radius: 14px;
      background-color: rgba(${forgeFocusRgb}, 0.3);
    }

    .window-tilepreview-stacked {
      border-width: 1px;
      border-color: rgba(247, 162, 43, 0.4);
      border-style: solid;
      border-radius: 14px;
      background-color: rgba(247, 162, 43, 0.3);
    }

    .window-tilepreview-swap {
      border-width: 1px;
      border-color: rgba(162, 247, 43, 0.4);
      border-style: solid;
      border-radius: 14px;
      background-color: rgba(162, 247, 43, 0.4);
    }

    .window-tilepreview-tabbed {
      border-width: 1px;
      border-color: rgba(18, 199, 224, 0.4);
      border-style: solid;
      border-radius: 14px;
      background-color: rgba(17, 199, 224, 0.3);
    }
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
        name = "Reversal-dark";
        package = pkgs.reversal-icon-theme;
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

    # Forge copies its upstream stylesheet here on first run and never touches it again
    xdg.configFile."forge/stylesheet/forge/stylesheet.css" = {
      text = forgeStylesheet;
      force = true; # overwrite the stale copy Forge dropped in
    };

    dconf.settings = {
      "org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
        icon-theme = "Reversal-dark";
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
