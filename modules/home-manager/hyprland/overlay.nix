{
  config,
  lib,
  pkgs,
  ...
}:

with lib;
let
  cfg = config.modules.hyprland;

  hyprAppDrawer = pkgs.writeShellScriptBin "hypr-app-drawer" ''
    exec wofi --show drun
  '';
in
{
  config = mkIf cfg.enable {
    home.packages = [ hyprAppDrawer ];
  };
}
