# Dormant - no host enables this currently. Kept for future use.
{ config, lib, pkgs, inputs, ... }:

with lib;
let cfg = config.modules.hyprland;
in {
  options.modules.hyprland = {
    enable = mkEnableOption "Hyprland compositor";
  };

  config = mkIf cfg.enable {
    programs.hyprland = {
      enable = true;
      package = inputs.hyprland.packages.${pkgs.system}.hyprland;
    };

    # programs.hyprland.enable already installs xdg-desktop-portal-hyprland via
    # its own xdg.portal.extraPortals, and desktop.nix already enables the
    # portal. No portal config needed here — explicitly adding it duplicates
    # the systemd user unit symlink and fails the build with "File exists".

    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
    };

    environment.systemPackages = with pkgs; [
      # Status bar for Wayland compositors; renders the top bar.
      waybar
      # Dmenu-style application launcher / menu for Wayland.
      wofi
      # Lightweight Wayland notification daemon (shows desktop notifications).
      mako
      # Wallpaper daemon from the Hyprland project.
      hyprpaper
      # Screen locker from the Hyprland project.
      hyprlock
      # CLI screenshot tool that captures Wayland output to an image.
      grim
      # Lets the user click/drag to select a region, printing its geometry.
      slurp
      # Command-line clipboard read/write for Wayland (wl-copy, wl-paste).
      wl-clipboard
      # Synthesizes keyboard input on Wayland (xdotool type equivalent).
      wtype
      # JSON parser used by helper scripts to read `hyprctl -j` output.
      jq
    ];

    # PAM service for hyprlock to authenticate unlock
    security.pam.services.hyprlock = { };
  };
}
