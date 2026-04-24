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
      package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    };

    # programs.hyprland.enable already installs xdg-desktop-portal-hyprland via
    # its own xdg.portal.extraPortals, and desktop.nix already enables the
    # portal. No portal config needed here — explicitly adding it duplicates
    # the systemd user unit symlink and fails the build with "File exists".

    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
    };

    # Hyprland ships lean and you add packages as needed
    environment.systemPackages = with pkgs; [
      waybar         # Status bar
      wofi            # App Launcher
      mako           # Notification daemon
      hyprpaper       # Wallpaper daemon - Hyprland Plugin
      hyprlock        # Screen locker - Hyprland Plugin
      grim            # Screenshot Tool
      slurp           # Grim Tool for Screenshots
      jq              # Util to parse script output
    ];

    # PAM service for hyprlock to authenticate unlock
    security.pam.services.hyprlock = { };
  };
}
