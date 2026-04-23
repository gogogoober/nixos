# Piper TTS with selection-to-speech keybind helper.
#
# Provides `speak-selection`: reads the current selection (primary, then
# clipboard fallback), pipes it to Piper, and plays via aplay. Toggles —
# pressing again while playing stops playback.
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.modules.tts;

  voiceName = "en_US-lessac-high";
  voiceBaseUrl = "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/lessac/high";

  voiceOnnx = pkgs.fetchurl {
    url = "${voiceBaseUrl}/${voiceName}.onnx";
    sha256 = "02cyrp5xsr5pr4y892i270zzxm1j4191c5aaycvp209qlv1zgasc";
  };

  voiceJson = pkgs.fetchurl {
    url = "${voiceBaseUrl}/${voiceName}.onnx.json";
    sha256 = "0bs1j8d97v6bsvfp82h50a23kckz1scfvf312ny5gwjrk1yvjhnv";
  };

  voice = pkgs.runCommand "piper-voice-${voiceName}" { } ''
    mkdir -p $out
    cp ${voiceOnnx} $out/${voiceName}.onnx
    cp ${voiceJson} $out/${voiceName}.onnx.json
  '';

  # Sample rate 22050 matches the lessac-high model. Change with the voice.
  speakSelection = pkgs.writeShellApplication {
    name = "speak-selection";
    runtimeInputs = with pkgs; [ piper-tts alsa-utils wl-clipboard procps ];
    text = ''
      if pkill -x piper 2>/dev/null; then
        pkill -x aplay 2>/dev/null || true
        exit 0
      fi

      text="$(wl-paste --primary --no-newline 2>/dev/null || true)"
      if [ -z "$text" ]; then
        text="$(wl-paste --no-newline 2>/dev/null || true)"
      fi
      if [ -z "$text" ]; then
        exit 0
      fi

      printf '%s' "$text" \
        | piper -m ${voice}/${voiceName}.onnx --output-raw 2>/dev/null \
        | aplay -q -r 22050 -f S16_LE -t raw -
    '';
  };
in {
  options.modules.tts = {
    enable = mkEnableOption "Piper TTS with speak-selection helper";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ speakSelection ];
  };
}
