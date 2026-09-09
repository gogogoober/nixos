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
    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true; # Stream to/from other devices
      localNetworkGameTransfers.openFirewall = true; # LAN game copies
      extraCompatPackages = [ pkgs.proton-ge-bin ]; # Better Proton compat
      gamescopeSession.enable = true; # "Steam (gamescope)" login session
    };

    programs.gamescope = {
      enable = true;
      capSysNice = true; # Let gamescope raise its own priority
    };

    programs.gamemode.enable = true;

    environment.systemPackages = with pkgs; [
      mangohud # In-game performance overlay
      protontricks # Per-game Proton config tool
    ];
  };
}
