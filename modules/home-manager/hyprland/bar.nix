{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib) mkIf;
  cfg = config.modules.hyprland;
  ds = import ../design-system;

  # Layout knobs
  barHeight = 28;
  barMargin = 3;
  fontFamily = "JetBrainsMono Nerd Font, monospace";
  fontSize = 12;

  # Stub for not-yet-wired clicks
  todo = "${pkgs.libnotify}/bin/notify-send 'Quick settings' 'Not wired yet'";

  # Custom WIFI: off / on-no-conn / low / mid / high (block-bar icons)
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
      printf '{"text":"WIFI ▁▁▁▁","class":"idle"}\n'
      exit 0
    fi
    signal=$(printf '%s' "$line" | awk -F: '{print $2}')
    ssid=$(printf '%s' "$line" | cut -d: -f3-)
    if [ "$signal" -lt 34 ]; then
      icon='▂▁▁▁'
    elif [ "$signal" -lt 67 ]; then
      icon='▂▃▄▁'
    else
      icon='▂▃▄▅'
    fi
    printf '{"text":"WIFI %s","tooltip":"%s · %s%%","class":"connected"}\n' "$icon" "$ssid" "$signal"
  '';

  brightnessScript = pkgs.writeShellScript "bar-brightness" ''
    set -eu
    pct=$(${pkgs.brightnessctl}/bin/brightnessctl -m | awk -F, '{gsub("%","",$4); print $4}')
    printf '{"text":"BRT %s%%"}\n' "$pct"
  '';

  # Music: Nerd Font glyph stays put; class swaps based on whether the
  # spotify-player process is alive so the icon shows green when running in
  # the background (popup hidden) and dim otherwise.
  musicScript = pkgs.writeShellScript "bar-music" ''
    set -eu
    if ${pkgs.procps}/bin/pgrep -x spotify_player >/dev/null 2>&1; then
      printf '{"text":"󰝚","class":"alive","tooltip":"spotify-player running"}\n'
    else
      printf '{"text":"󰝚","class":"idle","tooltip":"music"}\n'
    fi
  '';

  # Custom VOL module: polls wpctl so wiremix-driven changes show up too.
  # Built-in pulseaudio module is event-driven via libpulse, but wiremix talks
  # straight to PipeWire and those events do not always reach the compat layer.
  volumeScript = pkgs.writeShellScript "bar-volume" ''
    set -eu
    wpctl=${pkgs.wireplumber}/bin/wpctl
    out=$($wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null) || {
      printf '{"text":"VOL ?"}\n'
      exit 0
    }
    vol=$(printf '%s' "$out" | awk '{print int($2 * 100 + 0.5)}')
    if printf '%s' "$out" | grep -q MUTED; then
      printf '{"text":"VOL mute","class":"muted"}\n'
    else
      printf '{"text":"VOL %s%%"}\n' "$vol"
    fi
  '';

  # Dictate indicator: hidden when idle, green dot for 3s after delivery.
  # State file is written by the dictate Go helper; pkill -SIGRTMIN+10 nudges
  # waybar so the icon appears without waiting for the next poll.
  dictateScript = pkgs.writeShellScript "bar-dictate" ''
    set -eu
    state_file="''${XDG_RUNTIME_DIR:-/tmp}/dictate.state"
    if [ ! -f "$state_file" ]; then
      printf '{"text":"","class":"idle"}\n'
      exit 0
    fi
    state=$(cat "$state_file" 2>/dev/null || true)
    case "$state" in
      recording) printf '{"text":"●","class":"recording","tooltip":"dictating"}\n' ;;
      transcribing) printf '{"text":"●","class":"transcribing","tooltip":"transcribing"}\n' ;;
      ready)
        age=$(( $(date +%s) - $(${pkgs.coreutils}/bin/stat -c %Y "$state_file") ))
        if [ "$age" -lt 3 ]; then
          printf '{"text":"●","class":"ready","tooltip":"ready to paste"}\n'
        else
          printf '{"text":"","class":"idle"}\n'
        fi
        ;;
      *) printf '{"text":"","class":"idle"}\n' ;;
    esac
  '';

  weatherScript = pkgs.writeShellScript "bar-weather" ''
    set -eu
    city=$(quick-settings-get location.city 2>/dev/null || true)
    state=$(quick-settings-get location.state 2>/dev/null || true)
    units=$(quick-settings-get location.units 2>/dev/null || echo "imperial")
    case "$units" in
      metric) flag="m" ;;
      *)      flag="u" ;;
    esac
    # empty place makes wttr.in geolocate by IP
    place=""
    if [ -n "$city" ]; then
      place="$city"
      [ -n "$state" ] && place="$city,$state"
      place=$(${pkgs.jq}/bin/jq -rn --arg v "$place" '$v|@uri')
    fi
    # main text: temp only (stable width); tooltip carries the condition
    temp=$(${pkgs.curl}/bin/curl -s --max-time 5 "https://wttr.in/$place?format=%t&$flag" || true)
    cond=$(${pkgs.curl}/bin/curl -s --max-time 5 "https://wttr.in/$place?format=%C&$flag" || true)
    if [ -z "$temp" ]; then
      printf '{"text":"WX --","class":"offline"}\n'
      exit 0
    fi
    temp=$(printf '%s' "$temp" | tr -d '+')
    printf '{"text":"WX %s","tooltip":"%s"}\n' "$temp" "$cond"
  '';

  # Upgrade arrows: spin while nixos-upgrade runs, then rest green or red
  # until the next boot or a left click. Long-running script because waybar's
  # one second interval floor is too slow to read as rotation.
  upgradeFrameSec = "0.12";
  upgradePollSec = 2;
  upgradeProgressSec = 10;

  # Runtime dir, so the dismissed result comes back as cleared after a reboot
  upgradeStamp = ''"''${XDG_RUNTIME_DIR:-/tmp}/nixos-upgrade-seen"'';

  upgradeScript = pkgs.writeShellScript "bar-upgrade" ''
    set -u
    systemctl=${pkgs.systemd}/bin/systemctl
    journalctl=${pkgs.systemd}/bin/journalctl
    awk=${pkgs.gawk}/bin/awk
    stat=${pkgs.coreutils}/bin/stat
    sleep=${pkgs.coreutils}/bin/sleep
    date=${pkgs.coreutils}/bin/date

    frames=(← ↖ ↑ ↗ → ↘ ↓ ↙)
    rest_glyph="" # nerd font refresh arrows
    stamp=${upgradeStamp}

    frame=0
    polled_at=0
    progressed_at=0
    tooltip=""

    property() {
      $systemctl show nixos-upgrade.service -p "$1" --value 2>/dev/null || true
    }

    # Both plan headers nix prints up front, against the work logged since
    plan_lines="^(building '|copying path|these [0-9]+ (derivations will be built|paths will be fetched))"

    percent_done() {
      $journalctl -u nixos-upgrade.service -b -o cat -g "$plan_lines" 2>/dev/null | $awk '
        /^these [0-9]+ derivations will be built/ { planned_builds = $2; builds = 0; next }
        /^these [0-9]+ paths will be fetched/     { planned_fetches = $2; fetches = 0; next }
        /^building /    { builds++ }
        /^copying path/ { fetches++ }
        END {
          total = planned_builds + planned_fetches
          if (total < 1) exit
          pct = (builds + fetches) * 100 / total
          if (pct > 99) pct = 99
          printf "%d", pct
        }
      '
    }

    read_progress() {
      pct=$(percent_done)
      if [ -n "$pct" ]; then
        tooltip="NixOS is updating itself · $pct%"
      else
        tooltip="NixOS is updating itself"
      fi
      progressed_at=$($date +%s)
    }

    read_result() {
      # Needs ExecMain to have run: a week skipped by ConditionACPower never
      # starts, and systemd forgets the whole run at reboot
      ran=$(property ExecMainStartTimestamp)
      finished=$($date -d "$(property InactiveEnterTimestamp)" +%s 2>/dev/null || echo 0)
      dismissed=$($stat -c %Y "$stamp" 2>/dev/null || echo 0)
      if [ -z "$ran" ] || [ "$finished" -eq 0 ] || [ "$dismissed" -gt "$finished" ]; then
        text=""
        class=idle
        tooltip=""
      elif [ "$(property Result)" = success ]; then
        text="$rest_glyph"
        class=success
        tooltip="NixOS update successful · reboot to see the update"
      else
        text="$rest_glyph"
        class=error
        tooltip="NixOS update failed · right click for the log"
      fi
    }

    poll() {
      state=$(property ActiveState)
      if [ "$state" = active ] || [ "$state" = activating ]; then
        running=1
      else
        running=0
        read_result
      fi
      polled_at=$($date +%s)
    }

    while true; do
      now=$($date +%s)
      if [ $(( now - polled_at )) -ge ${toString upgradePollSec} ]; then
        poll
      fi
      if [ "$running" -eq 1 ]; then
        if [ $(( now - progressed_at )) -ge ${toString upgradeProgressSec} ]; then
          read_progress
        fi
        frame=$(( (frame + 1) % ''${#frames[@]} ))
        printf '{"text":"%s","class":"running","tooltip":"%s"}\n' "''${frames[frame]}" "$tooltip"
        $sleep ${upgradeFrameSec}
      else
        printf '{"text":"%s","class":"%s","tooltip":"%s"}\n' "$text" "$class" "$tooltip"
        $sleep ${toString upgradePollSec}
      fi
    done
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
        margin-top = barMargin;
        margin-left = barMargin;
        margin-right = barMargin;

        modules-left = [ "hyprland/workspaces" ];
        modules-center = [ "clock" ];
        modules-right = [
          "custom/weather"
          "custom/brightness"
          "custom/music"
          "custom/volume"
          "bluetooth"
          "custom/wifi"
          "custom/dictate"
          "custom/upgrade"
          "battery"
          "tray"
          "custom/power"
        ];

        "hyprland/workspaces" = {
          format = "[{id}]";
          on-click = "activate";
        };

        clock = {
          format = "{:%a %b %d %I:%M %p}";
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

        "custom/music" = {
          exec = musicScript;
          return-type = "json";
          interval = 2;
          on-click = "hypr-popup music";
        };

        "custom/volume" = {
          exec = volumeScript;
          return-type = "json";
          interval = 1;
          signal = 8; # popup sends SIGRTMIN+8 on dismiss for instant refresh
          on-click = "hypr-popup volume";
          on-scroll-up = "${pkgs.wireplumber}/bin/wpctl set-volume -l 0.8 @DEFAULT_AUDIO_SINK@ 5%+";
          on-scroll-down = "${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
        };

        bluetooth = {
          format = "BT";
          format-off = "BT off";
          format-connected = "BT ({num_connections})";
          tooltip-format-connected = "{device_enumerate}";
          on-click = "hypr-popup bluetooth";
        };

        "custom/wifi" = {
          exec = wifiScript;
          return-type = "json";
          interval = 5;
          signal = 9; # popup sends SIGRTMIN+9 on dismiss for instant refresh
          on-click = "hypr-popup wifi";
        };

        "custom/dictate" = {
          exec = dictateScript;
          return-type = "json";
          interval = 1;
          signal = 10; # dictate sends SIGRTMIN+10 on state change
        };

        "custom/upgrade" = {
          exec = upgradeScript;
          return-type = "json";
          restart-interval = 5; # no interval: the script streams its own frames
          on-click = "${pkgs.coreutils}/bin/touch ${upgradeStamp}"; # clear a resting result
          on-click-right = "ghostty -e ${pkgs.systemd}/bin/journalctl -u nixos-upgrade.service -b -f";
        };

        battery = {
          format = "BAT {capacity}%";
          format-charging = "BAT {capacity}% +";
          format-plugged = "BAT {capacity}% =";
          states = {
            warning = 20;
            critical = 10;
          };
          on-click = "hypr-popup battery";
        };

        tray = {
          spacing = 8;
        };

        "custom/power" = {
          format = "[ ⏻ ]";
          tooltip = false;
          on-click = "hypr-quick-settings power";
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
          background: ${ds.colors.background.deepest};
          color: ${ds.colors.text.primary};
          border: 1px solid ${ds.colors.surface.default};
        }

        #workspaces button,
        #clock,
        #custom-music,
        #custom-volume,
        #bluetooth,
        #battery,
        #tray,
        #custom-power,
        #custom-wifi,
        #custom-dictate,
        #custom-upgrade,
        #custom-weather,
        #custom-brightness {
          padding: 0 8px;
          margin: 0;
          background: transparent;
          color: ${ds.colors.text.primary};
          border-radius: 0;
        }

        /* dividers between right-cluster modules only */
        #custom-brightness,
        #custom-music,
        #custom-volume,
        #bluetooth,
        #custom-wifi,
        #custom-dictate,
        #custom-upgrade,
        #battery,
        #tray,
        #custom-power {
          border-left: 1px solid ${ds.colors.surface.default};
        }

        /* dictate sits between wifi and battery; collapse fully when idle so
           the bar layout does not bounce as the indicator appears */
        #custom-dictate.idle {
          padding: 0;
          border-left: none;
        }
        #custom-dictate.recording {
          color: ${ds.colors.text.error};
        }
        #custom-dictate.transcribing {
          color: ${ds.colors.text.warn};
        }
        #custom-dictate.ready {
          color: ${ds.colors.text.success};
        }

        /* same collapse treatment as dictate: no upgrade, no slot */
        #custom-upgrade.idle {
          padding: 0;
          border-left: none;
        }
        /* one glyph wide in every state, so neighbours never shift */
        #custom-upgrade.running,
        #custom-upgrade.success,
        #custom-upgrade.error {
          min-width: 16px;
        }
        #custom-upgrade.success {
          color: ${ds.colors.text.success};
        }
        #custom-upgrade.error {
          color: ${ds.colors.text.error};
        }

        /* fixed widths so right-cluster values do not bounce on update */
        #custom-weather    { min-width: 56px; }
        #custom-brightness { min-width: 64px; }
        #custom-volume        { min-width: 64px; }
        #bluetooth         { min-width: 56px; }
        #custom-wifi       { min-width: 72px; }
        #battery           { min-width: 80px; }

        #workspaces button {
          color: ${ds.colors.text.muted};
          padding: 0 6px;
        }
        #workspaces button.active {
          color: ${ds.colors.state.focus-ring};
        }
        #workspaces button:hover {
          background: ${ds.colors.surface.default};
          color: ${ds.colors.text.primary};
        }

        #clock:hover,
        #custom-music:hover,
        #custom-volume:hover,
        #bluetooth:hover,
        #custom-wifi:hover,
        #custom-weather:hover,
        #custom-brightness:hover,
        #custom-upgrade:hover,
        #custom-power:hover,
        #battery:hover {
          background: ${ds.colors.surface.default};
        }

        #custom-wifi.off,
        #custom-music.idle,
        #custom-volume.muted,
        #custom-weather.offline {
          color: ${ds.colors.text.disabled};
        }
        #custom-music.alive {
          color: ${ds.colors.text.success};
        }
        #battery.warning {
          color: ${ds.colors.text.warn};
        }
        #battery.critical {
          color: ${ds.colors.text.error};
        }
        #bluetooth.connected,
        #custom-wifi.connected {
          color: ${ds.colors.text.link};
        }
        #battery.charging {
          color: ${ds.colors.text.success};
        }
      '';
    };
  };
}
