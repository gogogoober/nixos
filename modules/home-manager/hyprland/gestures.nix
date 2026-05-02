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
        # 3-finger swipe up opens the app launcher
        "3, up, exec, hypr-popup launcher"
      ];
    };
  };
}
