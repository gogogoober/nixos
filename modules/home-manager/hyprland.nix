# Hyprland user config: keybinds, cheatsheet, lock-sleep, universal clipboard.
# Minimum-viable daily-driver session — monitor fallback, workspace keybinds,
# window focus navigation, notification daemon autostart. Build out further
# (waybar, hypridle, hyprlock, hyprsunset, theming) once the session proves out.
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.modules.hyprland;

  # Issue: helper scripts embed the nixpkgs-shipped Hyprland path via
  # ${pkgs.hyprland}/bin/hyprctl, but the system installs Hyprland from the
  # flake input (inputs.hyprland). If the IPC protocol ever diverges between
  # the two versions these scripts will break. Switch to bare `hyprctl` /
  # `jq` / `wofi` / `hyprlock` and rely on PATH.
  hyprClipboard = pkgs.writeShellScriptBin "hypr-clipboard" ''
    action="$1"
    class=$(${pkgs.hyprland}/bin/hyprctl activewindow -j | ${pkgs.jq}/bin/jq -r .class)
    case "$class" in
      kitty|Alacritty|foot|org.wezfurlong.wezterm) mod="CTRL SHIFT" ;;
      *) mod="CTRL" ;;
    esac
    case "$action" in
      copy)  key=c ;;
      paste) key=v ;;
      cut)   key=x ;;
    esac
    ${pkgs.hyprland}/bin/hyprctl dispatch sendshortcut "$mod, $key, activewindow"
  '';

  hyprCheatsheet = pkgs.writeShellScriptBin "hypr-cheatsheet" ''
    ${pkgs.hyprland}/bin/hyprctl binds -j \
      | ${pkgs.jq}/bin/jq -r '.[] | select(.description != "") | "\(.key)\t\(.description)"' \
      | ${pkgs.wofi}/bin/wofi --dmenu --prompt="Keybindings" --width=500 --height=600
  '';

  hyprLockSleep = pkgs.writeShellScriptBin "hypr-lock-sleep" ''
    ${pkgs.hyprlock}/bin/hyprlock --immediate &
    sleep 0.3
    ${pkgs.systemd}/bin/systemctl suspend
  '';

  # Workspace 1-9: switch with $mod, move window with $mod+SHIFT.
  workspaceBinds = builtins.concatMap (n: [
    "$mod,       ${toString n}, Switch to workspace ${toString n},       workspace, ${toString n}"
    "$mod SHIFT, ${toString n}, Move window to workspace ${toString n},  movetoworkspace, ${toString n}"
  ]) [ 1 2 3 4 5 6 7 8 9 ];
in {
  options.modules.hyprland = {
    enable = mkEnableOption "Hyprland home-manager config";
  };

  config = mkIf cfg.enable {
    home.packages = [ hyprClipboard hyprCheatsheet hyprLockSleep ];

    wayland.windowManager.hyprland = {
      enable = true;
      # NixOS module (modules/nixos/hyprland.nix) installs Hyprland system-wide
      # from the flake input. Suppress home-manager's user-level install to avoid
      # a duplicate Hyprland package and session-file confusion.
      package = null;
      portalPackage = null;

      settings = {
        "$mod" = "SUPER";

        # Catch-all: any output, preferred resolution, auto position, 1x scale.
        monitor = [ ",preferred,auto,1" ];

        # Wayland-friendly defaults for Electron + Firefox + Qt.
        env = [
          # Issue: NIXOS_OZONE_WL is also set in modules/nixos/hyprland.nix via
          # environment.sessionVariables. Pick one source of truth.
          "NIXOS_OZONE_WL,1"
          "MOZ_ENABLE_WAYLAND,1"
          "QT_QPA_PLATFORM,wayland;xcb"
          # Issue: XDG_SESSION_TYPE is set automatically by systemd-logind when
          # Hyprland is launched via its wayland-session .desktop file. This
          # line is redundant — remove it.
          "XDG_SESSION_TYPE,wayland"
        ];

        exec-once = [
          "mako"   # notification daemon
        ];

        general = {
          gaps_in = 2;
          gaps_out = 0;
          border_size = 1;
          "col.active_border" = "rgba(ccccffff)";
          "col.inactive_border" = "rgba(595959aa)";
          resize_on_border = true;
          allow_tearing = false;
          layout = "dwindle";
        };

        decoration = {
          rounding = 4;
          shadow = {
            enabled = true;
            range = 2;
            render_power = 3;
            color = "rgba(1a1a1aee)";
          };
          blur = {
            enabled = true;
            size = 3;
            passes = 1;
            vibrancy = 0.1696;
          };
        };

        # Smart gaps: drop borders/rounding/gaps when a workspace has a single
        # tiled window (w[tv1]) or is fullscreen (f[1]).
        workspace = [
          "w[tv1], gapsout:0, gapsin:0"
          "f[1], gapsout:0, gapsin:0"
        ];

        windowrule = [
          "border_size 0, rounding 0, match:float 0, match:workspace w[tv1]"
          "border_size 0, rounding 0, match:float 0, match:workspace f[1]"
        ];

        bindd = [
          "$mod,       T,      Open terminal,         exec, kitty"
          "$mod,       B,      Open browser,          exec, firefox"
          "$mod,       A,      Open Claude,           exec, kitty -e claude"
          "$mod,       W,      Close window,          killactive,"
          "$mod,       F,      Toggle fullscreen,     fullscreen, 0"
          "$mod,       SPACE,  App launcher,          exec, wofi --show drun"
          "$mod,       K,      Show keybindings,      exec, hypr-cheatsheet"
          # Issue: $mod+L invokes hypr-lock-sleep which locks AND suspends in
          # one action. Consider splitting: one bind to lock only (hyprlock),
          # another to suspend (hypr-lock-sleep).
          "$mod,       L,      Lock and sleep,        exec, hypr-lock-sleep"
          "$mod,       C,      Universal copy,        exec, hypr-clipboard copy"
          "$mod,       V,      Universal paste,       exec, hypr-clipboard paste"
          "$mod,       X,      Universal cut,         exec, hypr-clipboard cut"
          "SUPER,      escape, Speak selection,       exec, speak-selection"

          # Focus movement
          "$mod,       left,   Focus window left,     movefocus, l"
          "$mod,       right,  Focus window right,    movefocus, r"
          "$mod,       up,     Focus window up,       movefocus, u"
          "$mod,       down,   Focus window down,     movefocus, d"

          # Escape hatch — log out of Hyprland back to GDM.
          "$mod SHIFT, Q,      Exit Hyprland,         exit,"
        ] ++ workspaceBinds;
      };
    };
  };
}
