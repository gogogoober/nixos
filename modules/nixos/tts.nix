# Piper TTS with a warm-model daemon and selection-to-speech helper.
#
# Architecture:
#   piper-server (systemd user service) loads the voice once and keeps it in
#   memory, exposing piper's built-in HTTP API on 127.0.0.1.
#   speak-selection grabs the current selection and POSTs it to the daemon,
#   piping the returned WAV straight to aplay. Eliminates the ~2-3s cold-start
#   that one-shot `piper` invocations incur.
#
# Selection capture:
#   Try PRIMARY first (works in terminals, editors, native GTK apps). If empty,
#   synthesize Ctrl+C via ydotool so browsers/Electron apps copy their current
#   selection to the clipboard, then read the clipboard. Caveat: if no app has
#   a selection AND a terminal is focused with a running process, the synthetic
#   Ctrl+C will SIGINT it — uncommon, but worth knowing.
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

  # piper-tts ships only the one-shot CLI. Re-derive the python wrapper with
  # http_server as the entry point so we can run it as a long-lived server.
  piperServer = pkgs.runCommand "piper-server" { } ''
    mkdir -p $out/bin
    sed 's|from piper\.__main__ import main|from piper.http_server import main|' \
      ${pkgs.piper-tts}/bin/.piper-wrapped > $out/bin/.piper-server-wrapped
    chmod +x $out/bin/.piper-server-wrapped
    sed "s|${pkgs.piper-tts}/bin/.piper-wrapped|$out/bin/.piper-server-wrapped|g" \
      ${pkgs.piper-tts}/bin/piper > $out/bin/piper-server
    chmod +x $out/bin/piper-server
  '';

  port = "5174";

  speakSelection = pkgs.writeShellApplication {
    name = "speak-selection";
    runtimeInputs = with pkgs; [ alsa-utils wl-clipboard procps curl jq ydotool ];
    text = ''
      pkill -x aplay 2>/dev/null || true

      text="$(wl-paste --primary --no-newline 2>/dev/null || true)"

      # PRIMARY is empty for browsers/Electron; ask the focused app to copy.
      # 29 = KEY_LEFTCTRL, 46 = KEY_C; format is keycode:1 (down) / keycode:0 (up).
      if [ -z "$text" ]; then
        ydotool key 29:1 46:1 46:0 29:0 2>/dev/null || true
        sleep 0.1
        text="$(wl-paste --no-newline 2>/dev/null || true)"
      fi

      if [ -z "$text" ]; then
        exit 0
      fi

      curl -sS --max-time 60 -X POST \
        -H "Content-Type: application/json" \
        -d "$(jq -n --arg t "$text" '{text: $t}')" \
        "http://127.0.0.1:${port}/" \
      | aplay -q
    '';
  };
in {
  options.modules.tts = {
    enable = mkEnableOption "Piper TTS daemon + speak-selection helper";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ speakSelection ];

    # Provides ydotoold (system service) + ydotool client. Adds the ydotool
    # group; users invoking ydotool need to be in it.
    programs.ydotool.enable = true;

    systemd.user.services.piper-server = {
      description = "Piper TTS HTTP daemon (voice model kept warm in memory)";
      wantedBy = [ "default.target" ];
      serviceConfig = {
        ExecStart = "${piperServer}/bin/piper-server -m ${voice}/${voiceName}.onnx --host 127.0.0.1 --port ${port}";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };
  };
}
