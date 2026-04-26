{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

with lib;
let
  cfg = config.modules.hyprland;
in
{
  config = mkIf cfg.enable {
    wayland.windowManager.hyprland = {
      plugins = [ inputs.Hyprspace.packages.${pkgs.system}.Hyprspace ];

      # Drive the swipe from gestures.nix instead of Hyprspace's own grab
      settings."plugin:overview:disableGestures" = true;
    };
  };
}
