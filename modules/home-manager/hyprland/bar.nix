{
  config,
  lib,
  pkgs,
  ...
}:

with lib;
let
  cfg = config.modules.hyprland;

  # Layout knobs
  barHeight = 28;
  fontFamily = "JetBrainsMono Nerd Font, monospace";
  fontSize = 12;

  # Catppuccin Mocha tokens — see docs/design-system/colors.md
  crust    = "#11111b";
  surface0 = "#313244";
  text     = "#cdd6f4";
  overlay0 = "#6c7086";
  overlay1 = "#7f849c";
  blue     = "#89b4fa";
  green    = "#a6e3a1";
  yellow   = "#f9e2af";
  red      = "#f38ba8";
  lavender = "#b4befe";

  # Stub for not-yet-wired clicks
  todo = "${pkgs.libnotify}/bin/notify-send 'Quick settings' 'Not wired yet'";

  # Custom WIFI: distinguishes off / on-no-conn / connected
  wifiScript = pkgs.writeShellScript "bar-wifi" ''
    set -eu
    nmcli=${pkgs.networkmanager}/bin/nmcli
    radio=$($nmcli radio wifi)
    if [ "$radio" != "enabled" ]; then
      printf '{"text":"WIFI off","class":"off"}\n'
      exit 0
    fi
    line=$($nmcli -t -f active,signal,ssid dev wifi | awk -F: '$1=="yes" {print; exit}')
    if [ -z "$line" ]; then
      printf '{"text":"WIFI","class":"idle"}\n'
      exit 0
    fi
    signal=$(printf '%s' "$line" | awk -F: '{print $2}')
    ssid=$(printf '%s' "$line" | cut -d: -f3-)
    printf '{"text":"WIFI %s%%","tooltip":"%s","class":"connected"}\n' "$signal" "$ssid"
  '';

  brightnessScript = pkgs.writeShellScript "bar-brightness" ''
    set -eu
    pct=$(${pkgs.brightnessctl}/bin/brightnessctl -m | awk -F, '{gsub("%","",$4); print $4}')
    printf '{"text":"BRT %s%%"}\n' "$pct"
  '';

  weatherScript = pkgs.writeShellScript "bar-weather" ''
    set -eu
    city=$(quick-settings-get location.city 2>/dev/null || echo "New York")
    state=$(quick-settings-get location.state 2>/dev/null || echo "NY")
    units=$(quick-settings-get location.units 2>/dev/null || echo "imperial")
    case "$units" in
      metric) flag="m" ;;
      *)      flag="u" ;;
    esac
    out=$(${pkgs.curl}/bin/curl -s --max-time 5 "https://wttr.in/$city,$state?format=%t+%C&$flag" || true)
    if [ -z "$out" ]; then
      printf '{"text":"WX --","class":"offline"}\n'
      exit 0
    fi
    out=$(printf '%s' "$out" | tr -d '+')
    printf '{"text":"WX %s"}\n' "$out"
  '';
in
{
  config = mkIf cfg.enable {
    programs.waybar = {
      enable = true;
      # Hyprland exec-once launches waybar; disable the service to avoid double instance
      systemd.enable = false;

      settings.mainBar = {
        layer = "top";
        position = "top";
        height = barHeight;
        spacing = 0;

        modules-left = [ "hyprland/workspaces" ];
        modules-center = [ "clock" ];
        modules-right = [
          "custom/weather"
          "custom/brightness"
          "pulseaudio"
          "bluetooth"
          "custom/wifi"
          "battery"
          "tray"
          "custom/power"
        ];

        "hyprland/workspaces" = {
          format = "[{id}]";
          on-click = "activate";
        };

        clock = {
          format = "{:%a %b %d %H:%M}";
          tooltip-format = "<tt>{calendar}</tt>";
          on-click = todo; # TODO: open calendar overlay
        };

        "custom/weather" = {
          exec = weatherScript;
          return-type = "json";
          interval = 600;
          on-click = todo; # TODO: weather details
        };

        "custom/brightness" = {
          exec = brightnessScript;
          return-type = "json";
          interval = 2;
          on-click = todo; # TODO: brightness slider
          on-scroll-up = "${pkgs.brightnessctl}/bin/brightnessctl set +5%";
          on-scroll-down = "${pkgs.brightnessctl}/bin/brightnessctl set 5%-";
        };

        pulseaudio = {
          format = "VOL {volume}%";
          format-muted = "VOL mute";
          on-click = todo; # TODO: volume slider
          on-scroll-up = "${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+";
          on-scroll-down = "${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
        };

        bluetooth = {
          format = "BT";
          format-off = "BT off";
          format-connected = "BT ({num_connections})";
          tooltip-format-connected = "{device_enumerate}";
          on-click = "hypr-quick-settings bluetooth";
        };

        "custom/wifi" = {
          exec = wifiScript;
          return-type = "json";
          interval = 5;
          on-click = "hypr-quick-settings wifi";
        };

        battery = {
          format = "BAT {capacity}%";
          format-charging = "BAT {capacity}% +";
          format-plugged = "BAT {capacity}% =";
          states = {
            warning = 20;
            critical = 10;
          };
          on-click = todo; # TODO: power profile picker
        };

        tray = {
          spacing = 8;
        };

        "custom/power" = {
          format = "[ ⏻ ]";
          tooltip = false;
          on-click = "hypr-quick-settings";
        };
      };

      style = ''
        * {
          font-family: ${fontFamily};
          font-size: ${toString fontSize}px;
          min-height: 0;
          border-radius: 0;
        }

        window#waybar {
          background: ${crust};
          color: ${text};
          border-bottom: 1px solid ${surface0};
        }

        #workspaces button,
        #clock,
        #pulseaudio,
        #bluetooth,
        #battery,
        #tray,
        #custom-power,
        #custom-wifi,
        #custom-weather,
        #custom-brightness {
          padding: 0 10px;
          margin: 0;
          background: ${crust};
          color: ${text};
          border-radius: 0;
          border-left: 1px solid ${surface0};
        }

        #workspaces button:first-child {
          border-left: none;
        }

        #workspaces button {
          color: ${overlay1};
          padding: 0 6px;
        }
        #workspaces button.active {
          color: ${lavender};
        }
        #workspaces button:hover {
          background: ${surface0};
          color: ${text};
        }

        #clock:hover,
        #pulseaudio:hover,
        #bluetooth:hover,
        #custom-wifi:hover,
        #custom-weather:hover,
        #custom-brightness:hover,
        #custom-power:hover,
        #battery:hover {
          background: ${surface0};
        }

        #custom-wifi.off,
        #pulseaudio.muted,
        #custom-weather.offline {
          color: ${overlay0};
        }
        #battery.warning {
          color: ${yellow};
        }
        #battery.critical {
          color: ${red};
        }
        #bluetooth.connected,
        #custom-wifi.connected {
          color: ${blue};
        }
        #battery.charging {
          color: ${green};
        }
      '';
    };
  };
}
