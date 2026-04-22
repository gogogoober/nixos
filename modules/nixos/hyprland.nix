# Hyprland compositor: wayland compositor, per-compositor touch behavior
{ config, lib, pkgs, ... }:

with lib;
let cfg = config.modules.hyprland;
in {
  options.modules.hyprland = {
    enable = mkEnableOption "Hyprland compositor";
  };

  config = mkIf cfg.enable {
    # Hyprland config goes here
  };
}
