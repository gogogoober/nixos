{ config, lib, ... }:

let
  inherit (lib) mkIf;
  cfg = config.modules.hyprland;
in
{
  config = mkIf cfg.enable {
    wayland.windowManager.hyprland.settings = {
      decoration = {
        rounding = 4;
        shadow = {
          enabled = true;
          range = 2;
          render_power = 3;
          color = "rgba(1a1a1aee)";
        };
        blur = {
          enabled = true;
          size = 3;
          passes = 1;
          vibrancy = 0.1696;
        };
      };
    };
  };
}
