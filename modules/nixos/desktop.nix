# Shared graphical stack: pipewire, fonts, xdg portals, bluetooth, printing
{ config, lib, pkgs, ... }:

with lib;
let cfg = config.modules.desktop;
in {
  options.modules.desktop = {
    enable = mkEnableOption "shared desktop/graphical stack";
  };

  config = mkIf cfg.enable {
    # Desktop config goes here
  };
}
