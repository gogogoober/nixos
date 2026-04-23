# Text-to-speech system dependencies
#
# Piper is user-managed, NOT installed via Nix.
# - Piper lives in $HOME/.local/piper-venv
# - Voice model at $HOME/.local/share/piper-voices/en_US-lessac-high.onnx
# - speak-selection script reads clipboard, pipes to Piper, pipes to aplay
# - Do not install Piper via Nix
{ config, lib, pkgs, ... }:

with lib;
let cfg = config.modules.tts;
in {
  options.modules.tts = {
    enable = mkEnableOption "TTS system dependencies";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      alsa-utils
      wl-clipboard
    ];
  };
}
