# Common home config: base packages, XDG dirs, default dotfiles
{ config, lib, pkgs, ... }:

with lib;
let cfg = config.modules.common;
in {
  options.modules.common = {
    enable = mkEnableOption "common home configuration" // { default = true; };
  };

  config = mkIf cfg.enable {
    # Common home config goes here
  };
}
