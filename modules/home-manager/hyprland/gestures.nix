# Hyprland gesture only supports motion dispatchers; discrete gestures need hyprgrass
{ config, lib, ... }:

with lib;
let
  cfg = config.modules.hyprland;
in
{
  config = mkIf cfg.enable {
    wayland.windowManager.hyprland.settings = {
      # 3-finger horizontal swipe drags workspaces
      gesture = [
        "3, horizontal, workspace"
      ];
    };
  };
}
