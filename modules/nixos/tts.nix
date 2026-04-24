{
  config,
  lib,
  pkgs,
  ...
}:

with lib;
let
  cfg = config.modules.tts;

  settings = {
    # Browse voices at https://huggingface.co/rhasspy/piper-voices; update both shas when switching
    voiceName = "en_US-lessac-high";
    voiceBaseUrl = "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/lessac/high";
    voiceOnnxSha = "02cyrp5xsr5pr4y892i270zzxm1j4191c5aaycvp209qlv1zgasc";
    voiceJsonSha = "0bs1j8d97v6bsvfp82h50a23kckz1scfvf312ny5gwjrk1yvjhnv";

    host = "127.0.0.1";
    port = "5174";

    lengthScale = "0.85"; # <1 speaks faster, >1 slower
    noiseScale = "0.667";
    noiseWScale = "0.8";
    sentenceSilence = "0.2"; # seconds between sentences
    useCuda = false;

    selectionSleep = "0.08"; # seconds to wait after synthetic Ctrl+C
    maxChars = "50000"; # hard cap on chars sent to synth
  };

  voiceOnnx = pkgs.fetchurl {
    url = "${settings.voiceBaseUrl}/${settings.voiceName}.onnx";
    sha256 = settings.voiceOnnxSha;
  };

  voiceJson = pkgs.fetchurl {
    url = "${settings.voiceBaseUrl}/${settings.voiceName}.onnx.json";
    sha256 = settings.voiceJsonSha;
  };

  voice = pkgs.runCommand "piper-voice-${settings.voiceName}" { } ''
    mkdir -p $out
    cp ${voiceOnnx} $out/${settings.voiceName}.onnx
    cp ${voiceJson} $out/${settings.voiceName}.onnx.json
  '';

  # piper-tts ships CLI only; sed its wrapper into http_server. If nixpkgs changes wrapper shape, inspect .piper-wrapped.
  piperServer = pkgs.runCommand "piper-server" { } ''
    mkdir -p $out/bin
    sed 's|from piper\.__main__ import main|from piper.http_server import main|' \
      ${pkgs.piper-tts}/bin/.piper-wrapped > $out/bin/.piper-server-wrapped
    chmod +x $out/bin/.piper-server-wrapped
    sed "s|${pkgs.piper-tts}/bin/.piper-wrapped|$out/bin/.piper-server-wrapped|g" \
      ${pkgs.piper-tts}/bin/piper > $out/bin/piper-server
    chmod +x $out/bin/piper-server
  '';

  piperArgs = concatStringsSep " " (
    [
      "-m ${voice}/${settings.voiceName}.onnx"
      "--host ${settings.host}"
      "--port ${settings.port}"
      "--length-scale ${settings.lengthScale}"
      "--noise-scale ${settings.noiseScale}"
      "--noise-w-scale ${settings.noiseWScale}"
      "--sentence-silence ${settings.sentenceSilence}"
    ]
    ++ optional settings.useCuda "--cuda"
  );

  settingsPreamble = ''
    PIPER_HOST="${settings.host}"
    PIPER_PORT="${settings.port}"
    SELECTION_SLEEP="${settings.selectionSleep}"
    MAX_CHARS="${settings.maxChars}"
    LOCK_FILE="''${XDG_RUNTIME_DIR:-/tmp}/speak-selection.pgid"
    MAIN_LOCK="''${XDG_RUNTIME_DIR:-/tmp}/speak-selection.main.lock"
  '';

  speakSelection = pkgs.writeShellApplication {
    name = "speak-selection";
    runtimeInputs = with pkgs; [
      alsa-utils # aplay / wav playback
      curl # HTTP client to piper-server
      jq # JSON parser
      util-linux # setsid, flock
      wl-clipboard # Wayland clipboard access
      ydotool # Synthetic Ctrl+C fallback
    ];
    text = settingsPreamble + "\n" + builtins.readFile ./scripts/speak-selection.sh;
  };
in
{
  options.modules.tts = {
    enable = mkEnableOption "Piper TTS daemon + speak-selection hotkey helper";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ speakSelection ];

    # Creates "ydotool" group; host must add user to it for Ctrl+C fallback
    programs.ydotool.enable = true;

    systemd.user.services.piper-server = {
      description = "Piper TTS HTTP daemon (voice model kept warm in memory)";
      wantedBy = [ "default.target" ];
      serviceConfig = {
        ExecStart = "${piperServer}/bin/piper-server ${piperArgs}";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };
  };
}
