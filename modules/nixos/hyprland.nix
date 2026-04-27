{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

with lib;
let
  cfg = config.modules.hyprland;
in
{
  options.modules.hyprland = {
    enable = mkEnableOption "Hyprland compositor";
  };

  config = mkIf cfg.enable {
    programs.hyprland = {
      enable = true;
      package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    };

    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
    };

    # Hyprland ships lean and you add packages as needed
    environment.systemPackages = with pkgs; [
      waybar # Status bar
      wofi # App launcher
      mako # Notification daemon
      hyprpaper # Wallpaper daemon, Hyprland plugin
      hyprlock # Screen locker, Hyprland plugin
      grim # Screenshot tool
      slurp # Region picker for grim
      jq # JSON parser for helper scripts
    ];

    security.pam.services.hyprlock = { };

    home-manager.users.${config.modules.user.name}.modules.hyprland.enable = true;
  };
}
