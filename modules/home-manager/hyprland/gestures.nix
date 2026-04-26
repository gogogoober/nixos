{ config, lib, ... }:

with lib;
let
  cfg = config.modules.hyprland;
in
{
  config = mkIf cfg.enable {
    wayland.windowManager.hyprland.settings = {
      gesture = [
        # 3-finger horizontal swipe drags workspaces
        "3, horizontal, workspace"
        # 4-finger up opens Hyprspace overview
        "4, up, dispatcher, overview:toggle"
      ];
    };
  };
}
