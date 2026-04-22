# Common system configuration: locale, timezone, nix settings, base packages
{ config, lib, pkgs, ... }:

with lib;
let cfg = config.modules.common;
in {
  options.modules.common = {
    enable = mkEnableOption "common system configuration" // { default = true; };
  };

  config = mkIf cfg.enable {
    # Base system config goes here
  };
}
