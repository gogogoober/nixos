{ config, lib, ... }:

let
  inherit (lib) mkEnableOption mkIf;
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
