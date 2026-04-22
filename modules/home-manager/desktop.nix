# Home desktop configuration: GTK/Qt theming, cursor, wallpaper, app defaults
{ config, lib, pkgs, ... }:

with lib;
let cfg = config.modules.desktop;
in {
  options.modules.desktop = {
    enable = mkEnableOption "home desktop configuration";
  };

  config = mkIf cfg.enable {
    # Home desktop config goes here
  };
}
