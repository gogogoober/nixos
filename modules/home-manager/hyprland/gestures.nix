{ config, lib, ... }:

let
  inherit (lib) mkIf;
  cfg = config.modules.hyprland;
in
{
  config = mkIf cfg.enable {
    wayland.windowManager.hyprland.settings = {
      gesture = [
        # 3-finger horizontal swipe drags workspaces
        "3, horizontal, workspace"
      ];
    };
  };
}
