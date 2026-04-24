# Speech-to-text system dependencies
# VocalLinux is installed and managed by the user.
# wtype and wl-clipboard (required for STT typing + clipboard) live in
# desktop.nix since they're baseline Wayland tools shared with TTS.
{ config, lib, ... }:

with lib;
let
  cfg = config.modules.stt;
in
{
  options.modules.stt = {
    enable = mkEnableOption "STT system dependencies";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ ];
  };
}
