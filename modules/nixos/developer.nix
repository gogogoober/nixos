# Developer tools: compilers, language runtimes, development utilities
{ config, lib, pkgs, ... }:

with lib;
let cfg = config.modules.developer;
in {
  options.modules.developer = {
    enable = mkEnableOption "developer tools and utilities";
  };

  config = mkIf cfg.enable {
    # Developer config goes here
  };
}
