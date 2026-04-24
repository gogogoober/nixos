{ config, lib, ... }:

with lib;
let
  cfg = config.modules.hyprland;
in
{
  config = mkIf cfg.enable {
  };
}
