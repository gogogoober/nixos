{ config, lib, ... }:

let
  inherit (lib) mkIf;
  cfg = config.modules.hyprland;
in
{
  config = mkIf cfg.enable {
    wayland.windowManager.hyprland.settings = {
      input = {
        natural_scroll = true;
        touchpad = {
          natural_scroll = true;
        };
      };
    };
  };
}
