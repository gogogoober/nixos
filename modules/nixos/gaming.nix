{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf;
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
      mangohud # In-game performance overlay
      protontricks # Per-game Proton config tool
    ];
  };
}
