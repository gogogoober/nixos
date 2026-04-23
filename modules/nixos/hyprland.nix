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

    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-hyprland ];
    };

    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
    };

    environment.systemPackages = with pkgs; [
      waybar
      wofi
      mako
      hyprpaper
      grim
      slurp
      wl-clipboard
      wtype
    ];
  };
}
