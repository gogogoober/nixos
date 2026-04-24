# Hyprland user config — split by concern so each area is easy to find.
# Each sub-file is its own home-manager module gated on modules.hyprland.enable
# and writes into a distinct subtree of wayland.windowManager.hyprland.settings.
{ config, lib, ... }:

with lib;
let cfg = config.modules.hyprland;
in {
  imports = [
    ./startup.nix         # monitor, env vars, exec-once autostart
    ./keybinds.nix        # $mod binds + helper scripts
    ./tiling.nix          # gaps, borders, layout engine, fullscreen rules
    ./windows.nix         # per-window aesthetic: rounding, blur, shadow
    ./gestures.nix        # touchpad gestures
    ./bar.nix             # waybar config + styling
    ./overlay.nix         # app drawer + power menu (shared popover UI/UX)
    ./quick-settings.nix  # quick settings panel (placeholder)
  ];

  options.modules.hyprland = {
    enable = mkEnableOption "Hyprland home-manager config";
  };

  config = mkIf cfg.enable {
    wayland.windowManager.hyprland = {
      enable = true;
      # NixOS module (modules/nixos/hyprland.nix) installs Hyprland system-wide
      # from the flake input. Suppress home-manager's user-level install to avoid
      # a duplicate Hyprland package and session-file confusion.
      package = null;
      portalPackage = null;
    };
  };
}
