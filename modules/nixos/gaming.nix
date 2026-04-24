# Gaming: Steam, gamemode, mangohud, protontricks
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;
let
  cfg = config.modules.gaming;
in
{
  options.modules.gaming = {
    enable = mkEnableOption "gaming support";
  };

  config = mkIf cfg.enable {
    programs.steam.enable = true;
    programs.gamemode.enable = true;

    environment.systemPackages = with pkgs; [
      mangohud
      protontricks
    ];
  };
}
