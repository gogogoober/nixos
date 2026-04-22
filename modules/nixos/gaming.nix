# Gaming: Steam, gamepad drivers, performance tweaks
{ config, lib, pkgs, ... }:

with lib;
let cfg = config.modules.gaming;
in {
  options.modules.gaming = {
    enable = mkEnableOption "gaming support";
  };

  config = mkIf cfg.enable {
    # Gaming config goes here
  };
}
