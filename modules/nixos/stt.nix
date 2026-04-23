# Speech-to-text system dependencies
# VocalLinux is installed and managed by the user.
# wtype is required for typing into focused windows.
{ config, lib, pkgs, ... }:

with lib;
let cfg = config.modules.stt;
in {
  options.modules.stt = {
    enable = mkEnableOption "STT system dependencies";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      wtype
      wl-clipboard
    ];
  };
}
