# Terminal configuration: terminal emulator
{ config, lib, pkgs, ... }:

with lib;
let cfg = config.modules.terminal;
in {
  options.modules.terminal = {
    enable = mkEnableOption "terminal configuration";
  };

  config = mkIf cfg.enable {
    programs.alacritty = {
      enable = true;
      settings = {
        font = {
          normal.family = "JetBrainsMono Nerd Font";
          size = 12.0;
        };
        window = {
          padding = { x = 8; y = 8; };
          opacity = 0.95;
        };
      };
    };
  };
}
