# Terminal configuration: kitty
{ config, lib, pkgs, ... }:

with lib;
let cfg = config.modules.terminal;
in {
  options.modules.terminal = {
    enable = mkEnableOption "terminal configuration";
  };

  config = mkIf cfg.enable {
    programs.kitty = {
      enable = true;
      font = {
        name = "JetBrainsMono Nerd Font";
        size = 12;
      };
      # Theming placeholder - add catppuccin or similar here
    };
  };
}
