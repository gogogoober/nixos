# Waybar (the top bar): modules, layout, and CSS styling. Launched via
# exec-once in session.nix; the systemd user service is disabled so there's
# exactly one instance.
{ config, lib, ... }:

with lib;
let
  cfg = config.modules.hyprland;
in
{
  config = mkIf cfg.enable {
    programs.waybar = {
      enable = true;
      # Disable the home-manager user-service so waybar is only launched once,
      # via Hyprland's exec-once. The systemd service sometimes races with the
      # session and can pass flags that conflict with the exec-once instance.
      systemd.enable = false;
      settings.mainBar = {
        layer = "top";
        position = "top";
        height = 30;

        modules-left = [ "hyprland/workspaces" ];
        modules-center = [ "clock" ];
        modules-right = [
          "tray"
          "pulseaudio"
          "network"
          "battery"
          "custom/power"
        ];

        "hyprland/workspaces" = {
          format = "{id}";
          on-click = "activate";
        };

        clock = {
          format = "{:%a %b %d  %H:%M}";
          tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
        };

        network = {
          format-wifi = "Wi-Fi {signalStrength}%";
          format-ethernet = "Ethernet";
          format-disconnected = "Offline";
          tooltip-format = "{ipaddr}";
        };

        pulseaudio = {
          format = "Vol {volume}%";
          format-muted = "Vol Muted";
          on-click = "pavucontrol";
        };

        battery = {
          format = "Bat {capacity}%";
          states = {
            warning = 20;
            critical = 10;
          };
        };

        tray = {
          spacing = 8;
        };

        "custom/power" = {
          format = "⏻";
          tooltip = false;
          on-click = "hypr-power-menu";
        };
      };

      style = ''
        * {
          font-family: "Cantarell", "Inter", sans-serif;
          font-size: 13px;
        }
        window#waybar {
          background: rgba(30, 30, 30, 0.9);
          color: #e0e0e0;
        }
        #workspaces button {
          padding: 0 10px;
          background: transparent;
          color: #888;
          border: none;
        }
        #workspaces button.active {
          color: #fff;
          background: rgba(255, 255, 255, 0.12);
        }
        #clock, #network, #pulseaudio, #battery, #tray, #custom-power {
          padding: 0 12px;
        }
        #custom-power { color: #ddd; }
        #custom-power:hover { color: #fff; background: rgba(255, 255, 255, 0.12); }
        #battery.warning { color: #f9b500; }
        #battery.critical { color: #f44336; }
      '';
    };
  };
}
