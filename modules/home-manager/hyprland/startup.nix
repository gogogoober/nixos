# What launches when the Hyprland session starts: monitor layout, environment
# variables exported to every child process, and one-shot exec commands.
{ config, lib, ... }:

with lib;
let
  cfg = config.modules.hyprland;
in
{
  config = mkIf cfg.enable {
    wayland.windowManager.hyprland.settings = {
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
        "mako" # notification daemon
        "waybar" # top bar
      ];
    };
  };
}
