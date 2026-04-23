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
      themeFile = "tokyo_night_night";
      settings = {
        tab_bar_style = "powerline";
        tab_powerline_style = "slanted";
        tab_bar_min_tabs = 1;
        window_padding_width = 8;
        scrollback_lines = 10000;
        enable_audio_bell = "no";
        visual_bell_duration = "0";
        window_alert_on_bell = "no";
        bell_on_tab = "no";
      };
    };
  };
}
