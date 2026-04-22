# Terminal configuration: terminal emulator, themes, fonts
{ config, lib, pkgs, ... }:

with lib;
let cfg = config.modules.terminal;
in {
  options.modules.terminal = {
    enable = mkEnableOption "terminal configuration";
  };

  config = mkIf cfg.enable {
    # Terminal config goes here
  };
}
