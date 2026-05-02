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

  px = n: "${toString n}px";

  # Dedicated wofi stylesheet for quick settings. Monospace lets printf
  # padding line up the trailing icon column across rows.
  style = ''
    * {
      font-family: "JetBrainsMono Nerd Font", monospace;
      font-size: 14px;
      outline: none;
    }

    window {
      background-color: ${ds.colors.background.deepest};
      border: ${px ds.structure.border-width.thin} solid ${ds.colors.border.default};
      border-radius: ${px ds.structure.radius.md};
      color: ${ds.colors.text.primary};
    }

    #outer-box,
    #scroll {
      background-color: transparent;
      padding: 0;
      margin: 0;
    }

    #inner-box {
      background-color: transparent;
      margin: 0;
      padding: ${px ds.structure.spacing.xs};
    }

    #entry {
      margin: 0 ${px ds.structure.spacing.xs};
      padding: 0;
      background-color: transparent;
      border-radius: ${px ds.structure.radius.sm};
      min-height: ${px ds.structure.row-height.default};
    }

    #entry:selected {
      background-color: ${ds.colors.state.hover};
    }

    #text {
      color: ${ds.colors.text.primary};
      padding: ${px ds.structure.spacing.sm} ${px ds.structure.spacing.md};
    }
  '';

  # Layout knobs. labelPad is the column the trailing icon lands at,
  # tuned against menuWidth + the entry padding in `style`.
  labelPad = 28;
  listLabelPad = 32;
  menuWidth = 360;
  listWidth = 460;

  hyprQuickSettings = pkgs.writeShellScriptBin "hypr-quick-settings" ''
    set -eu
    self="$0"

    nmcli=${pkgs.networkmanager}/bin/nmcli
    btctl=${pkgs.bluez}/bin/bluetoothctl
    hyprlock=${pkgs.hyprlock}/bin/hyprlock
    sysctl=${pkgs.systemd}/bin/systemctl
    hyprctl=${pkgs.hyprland}/bin/hyprctl
    wofi=${pkgs.wofi}/bin/wofi

    style="$HOME/.config/wofi/quick-settings.css"

    pick() {
      "$wofi" --dmenu --hide-search --allow-markup --style "$style" \
        --prompt "$1" --width "$2" --height "$3"
    }

    ask_password() {
      "$wofi" --dmenu --password --allow-markup --style "$style" \
        --prompt "$1" --width 380 --height 80
    }

    # Pad an ASCII label so the trailing icon sits in a fixed column
    fmt() { printf '%-${toString labelPad}s%s' "$1" "$2"; }

    show_top() {
      choice=$(printf '%s\n' \
        "$(fmt 'Wi-Fi'     '󰖩')" \
        "$(fmt 'Bluetooth' '󰂯')" \
        "$(fmt 'Power'     '󰐥')" \
        | pick 'Quick Settings' ${toString menuWidth} 230)
      case "$choice" in
        Wi-Fi*)     exec "$self" wifi ;;
        Bluetooth*) exec "$self" bluetooth ;;
        Power*)     exec "$self" power ;;
      esac
    }

    wifi_glyph() {
      if   [ "$1" -ge 75 ]; then printf '󰤨'
      elif [ "$1" -ge 50 ]; then printf '󰤥'
      elif [ "$1" -ge 25 ]; then printf '󰤢'
      else                       printf '󰤟'
      fi
    }

    show_wifi() {
      $nmcli device wifi rescan >/dev/null 2>&1 || true
      rows=$($nmcli -t -f SSID,SIGNAL,SECURITY device wifi list \
        | awk -F: '$1 != ""' \
        | while IFS=: read -r ssid sig sec; do
            lock=' '
            [ -n "$sec" ] && lock='󰌾'
            glyph=$(wifi_glyph "$sig")
            printf '%-${toString listLabelPad}s %s  %s\n' "$ssid" "$glyph" "$lock"
          done)
      [ -z "$rows" ] && exit 0
      choice=$(printf '%s\n' "$rows" | pick 'Wi-Fi' ${toString listWidth} 460)
      [ -z "$choice" ] && exit 0
      ssid=$(printf '%s' "$choice" | sed -E 's/[[:space:]]+(󰤨|󰤥|󰤢|󰤟).*$//; s/[[:space:]]+$//')
      if printf '%s' "$choice" | grep -q '󰌾'; then
        pw=$(ask_password "Password for $ssid")
        [ -z "$pw" ] && exit 0
        printf '%s\n' "$pw" | $nmcli --ask device wifi connect "$ssid"
      else
        $nmcli device wifi connect "$ssid"
      fi
    }

    bt_glyph() {
      info=$($btctl info "$1" 2>/dev/null || true)
      if printf '%s' "$info" | grep -q 'Connected: yes'; then printf '󰂱'
      elif printf '%s' "$info" | grep -q 'Paired: yes'; then printf '󰂯'
      else                                                    printf '󰂲'
      fi
    }

    show_bluetooth() {
      ( $btctl --timeout 8 scan on >/dev/null 2>&1 & )
      sleep 1
      menu=""
      while IFS= read -r line; do
        [ -z "$line" ] && continue
        mac=$(printf '%s' "$line" | awk '{print $2}')
        name=$(printf '%s' "$line" | sed 's/^Device [^ ]* //')
        glyph=$(bt_glyph "$mac")
        # Tab separates the rendered display from the mac so we can
        # round-trip the selection back to a device id.
        row=$(printf '%-${toString listLabelPad}s %s\t%s' "$name" "$glyph" "$mac")
        menu=$(printf '%s%s\n' "$menu" "$row")
      done < <($btctl devices)
      [ -z "$menu" ] && exit 0
      choice=$(printf '%s' "$menu" | pick 'Bluetooth' ${toString listWidth} 460)
      [ -z "$choice" ] && exit 0
      mac=$(printf '%s' "$choice" | awk -F'\t' '{print $2}')
      [ -z "$mac" ] && exit 0
      exec "$self" bluetooth-device "$mac"
    }

    show_bluetooth_device() {
      mac=$1
      info=$($btctl info "$mac")
      paired=no
      connected=no
      printf '%s' "$info" | grep -q 'Paired: yes' && paired=yes
      printf '%s' "$info" | grep -q 'Connected: yes' && connected=yes

      if [ "$paired" = no ]; then
        rows=$(fmt 'Pair' '󰂱')
      elif [ "$connected" = no ]; then
        rows=$(printf '%s\n%s' \
          "$(fmt 'Connect' '󰂱')" \
          "$(fmt 'Forget'  '󰅖')")
      else
        rows=$(printf '%s\n%s' \
          "$(fmt 'Disconnect' '󰂲')" \
          "$(fmt 'Forget'     '󰅖')")
      fi

      choice=$(printf '%s\n' "$rows" | pick 'Device' ${toString menuWidth} 200)
      case "$choice" in
        Pair*)       $btctl pair "$mac" && $btctl connect "$mac" ;;
        Connect*)    $btctl connect "$mac" ;;
        Disconnect*) $btctl disconnect "$mac" ;;
        Forget*)     $btctl remove "$mac" ;;
      esac
    }

    show_power() {
      choice=$(printf '%s\n' \
        "$(fmt 'Lock'     '󰌾')" \
        "$(fmt 'Sleep'    '󰒲')" \
        "$(fmt 'Log Out'  '󰍃')" \
        "$(fmt 'Restart'  '󰜉')" \
        "$(fmt 'Shutdown' '󰐥')" \
        | pick 'Power' ${toString menuWidth} 320)
      case "$choice" in
        Lock*)     exec $hyprlock ;;
        Sleep*)    $sysctl suspend ;;
        Log\ Out*) $hyprctl dispatch exit ;;
        Restart*)  $sysctl reboot ;;
        Shutdown*) $sysctl poweroff ;;
      esac
    }

    case "''${1:-}" in
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
    xdg.configFile."wofi/quick-settings.css".text = style;
  };
}
