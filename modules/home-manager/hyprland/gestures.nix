# Touchpad gestures. Hyprland 0.54's built-in `gesture` keyword only accepts
# motion-capable dispatchers (workspace/move/…); discrete "swipe-up → launch
# app" needs the hyprgrass plugin or an external gesture daemon — deferred.
{ config, lib, ... }:

with lib;
let cfg = config.modules.hyprland;
in {
  config = mkIf cfg.enable {
    wayland.windowManager.hyprland.settings = {
      # Continuous 3-finger horizontal swipe drags workspaces.
      gesture = [
        "3, horizontal, workspace"
      ];
    };
  };
}
