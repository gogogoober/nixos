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
    warnings = [
      "modules.stt.enable is on but no STT pipeline is wired up yet (see .ai/prds/11-speech-to-text.md). The flag currently does nothing."
    ];
  };
}
