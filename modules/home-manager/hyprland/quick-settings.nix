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
      font-size: 18px;
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
      min-height: ${px ds.structure.row-height.comfortable};
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
  labelPad = 20;
  menuWidth = 280;

  hyprQuickSettings = pkgs.writeShellScriptBin "hypr-quick-settings" ''
    set -eu
    hyprlock=${pkgs.hyprlock}/bin/hyprlock
    sysctl=${pkgs.systemd}/bin/systemctl
    hyprctl=${pkgs.hyprland}/bin/hyprctl
    wofi=${pkgs.wofi}/bin/wofi

    style="$HOME/.config/wofi/quick-settings.css"

    pick() {
      "$wofi" --dmenu --hide-search --allow-markup --style "$style" \
        --prompt "$1" --width "$2" --height "$3"
    }

    # Pad an ASCII label so the trailing icon sits in a fixed column
    fmt() { printf '%-${toString labelPad}s%s' "$1" "$2"; }

    show_power() {
      choice=$(printf '%s\n' \
        "$(fmt 'Lock'     '󰌾')" \
        "$(fmt 'Sleep'    '󰒲')" \
        "$(fmt 'Log Out'  '󰍃')" \
        "$(fmt 'Restart'  '󰜉')" \
        "$(fmt 'Shutdown' '󰐥')" \
        | pick 'Power' ${toString menuWidth} 280)
      case "$choice" in
        Lock*)     exec $hyprlock ;;
        Sleep*)    $sysctl suspend ;;
        Log\ Out*) $hyprctl dispatch exit ;;
        Restart*)  $sysctl reboot ;;
        Shutdown*) $sysctl poweroff ;;
      esac
    }

    case "''${1:-}" in
      "" | power) show_power ;;
    esac
  '';
in
{
  config = mkIf cfg.enable {
    home.packages = [ hyprQuickSettings ];
    xdg.configFile."wofi/quick-settings.css".text = style;
  };
}
