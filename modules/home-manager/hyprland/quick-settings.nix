{
  config,
  lib,
  pkgs,
  ...
}:

with lib;
let
  cfg = config.modules.hyprland;

  hyprQuickSettings = pkgs.writeShellScriptBin "hypr-quick-settings" ''
    self="$0"

    wofi="${pkgs.wofi}/bin/wofi --dmenu"
    nmcli="${pkgs.networkmanager}/bin/nmcli"
    btctl="${pkgs.bluez}/bin/bluetoothctl"
    hyprlock="${pkgs.hyprlock}/bin/hyprlock"
    sysctl="${pkgs.systemd}/bin/systemctl"

    show_top() {
      choice=$(printf '%s\n' Wifi Bluetooth Power \
        | $wofi --prompt="Quick Settings" --width=260 --height=220)
      case "$choice" in
        Wifi)      exec "$self" wifi ;;
        Bluetooth) exec "$self" bluetooth ;;
        Power)     exec "$self" power ;;
      esac
    }

    show_wifi() {
      $nmcli device wifi rescan >/dev/null 2>&1 || true
      rows=$($nmcli -t -f SSID,SIGNAL,SECURITY device wifi list \
        | awk -F: '$1 != "" {
            lock = ($3 == "" ? "·" : "🔒")
            printf "%s  %s%%  %s\n", $1, $2, lock
          }')
      choice=$(printf '← Back\n%s' "$rows" \
        | $wofi --prompt="Wi-Fi" --width=380 --height=420)
      case "$choice" in
        "")       exit 0 ;;
        "← Back") exec "$self" ;;
        *)
          ssid=$(printf '%s' "$choice" | sed 's/  [0-9]*%.*$//')
          if printf '%s' "$choice" | grep -q '🔒'; then
            pw=$($wofi --password --prompt="Password for $ssid")
            [ -z "$pw" ] && exit 0
            printf '%s\n' "$pw" | $nmcli --ask device wifi connect "$ssid"
          else
            $nmcli device wifi connect "$ssid"
          fi
          ;;
      esac
    }

    show_bluetooth() {
      ( $btctl --timeout 8 scan on >/dev/null 2>&1 & )
      sleep 1
      menu="← Back"
      while IFS= read -r line; do
        [ -z "$line" ] && continue
        mac=$(printf '%s' "$line" | awk '{print $2}')
        name=$(printf '%s' "$line" | sed 's/^Device [^ ]* //')
        info=$($btctl info "$mac" 2>/dev/null)
        if printf '%s' "$info" | grep -q 'Connected: yes'; then
          glyph='●'
        elif printf '%s' "$info" | grep -q 'Paired: yes'; then
          glyph='○'
        else
          glyph='·'
        fi
        menu=$(printf '%s\n%s %s\t%s' "$menu" "$glyph" "$name" "$mac")
      done < <($btctl devices)
      choice=$(printf '%s\n' "$menu" | $wofi --prompt="Bluetooth" --width=380 --height=420)
      case "$choice" in
        "")       exit 0 ;;
        "← Back") exec "$self" ;;
        *)
          mac=$(printf '%s' "$choice" | awk -F'\t' '{print $2}')
          [ -z "$mac" ] && exit 0
          exec "$self" bluetooth-device "$mac"
          ;;
      esac
    }

    show_bluetooth_device() {
      mac="$1"
      info=$($btctl info "$mac")
      paired=no
      connected=no
      printf '%s' "$info" | grep -q 'Paired: yes' && paired=yes
      printf '%s' "$info" | grep -q 'Connected: yes' && connected=yes

      if [ "$paired" = no ]; then
        actions=$(printf 'Pair\nCancel')
      elif [ "$connected" = no ]; then
        actions=$(printf 'Connect\nForget\nCancel')
      else
        actions=$(printf 'Disconnect\nForget\nCancel')
      fi

      choice=$(printf '← Back\n%s' "$actions" \
        | $wofi --prompt="Device" --width=260 --height=220)
      case "$choice" in
        "")              exit 0 ;;
        "← Back"|Cancel) exec "$self" bluetooth ;;
        Pair)            $btctl pair "$mac" && $btctl connect "$mac" ;;
        Connect)         $btctl connect "$mac" ;;
        Disconnect)      $btctl disconnect "$mac" ;;
        Forget)          $btctl remove "$mac" ;;
      esac
    }

    show_power() {
      choice=$(printf '%s\n' '✕ Close' Lock Sleep Restart Shutdown \
        | $wofi --hide-search --prompt="Power" --width=260 --height=260)
      case "$choice" in
        ""|"✕ Close") exit 0 ;;
        Lock)         exec $hyprlock ;;
        Sleep)        $sysctl suspend ;;
        Restart)      $sysctl reboot ;;
        Shutdown)     $sysctl poweroff ;;
      esac
    }

    case "$1" in
      "")               show_top ;;
      wifi)             show_wifi ;;
      bluetooth)        show_bluetooth ;;
      bluetooth-device) show_bluetooth_device "$2" ;;
      power)            show_power ;;
    esac
  '';
in
{
  config = mkIf cfg.enable {
    home.packages = [ hyprQuickSettings ];
  };
}
