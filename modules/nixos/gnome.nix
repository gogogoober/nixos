# GNOME desktop environment: GDM, GNOME shell, extensions
{ config, lib, pkgs, ... }:

with lib;
let cfg = config.modules.gnome;
in {
  options.modules.gnome = {
    enable = mkEnableOption "GNOME desktop environment";
  };

  config = mkIf cfg.enable {
    # GNOME config goes here
  };
}
