{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    mkEnableOption
    mkIf
    concatStringsSep
    makeBinPath
    ;
  cfg = config.modules.stt;

  settings = {
    # ggml-base.en is the right balance for the 8 GB Surface Go 3; bump to small.en for batch, drop to tiny.en if pressed for latency
    modelUrl = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin";
    modelHash = "sha256-oDd5yG3zMjB19eeWyyzlAp8A7Ihp7uP9+4l6/jbG0AI=";

    vadModelUrl = "https://huggingface.co/ggml-org/whisper-vad/resolve/main/ggml-silero-v5.1.2.bin";
    vadModelHash = "sha256-KZQNmNQrkfvQXOSJ8+z3xy8KQvAn5IdZGaKPtMBOos8=";

    host = "127.0.0.1";
    port = "5175";
    threads = "2"; # 2c/4t Amber Lake-Y, fanless: hyperthreading hurts more than helps
  };

  whisperModel = pkgs.fetchurl {
    url = settings.modelUrl;
    hash = settings.modelHash;
  };
  vadModel = pkgs.fetchurl {
    url = settings.vadModelUrl;
    hash = settings.vadModelHash;
  };

  whisperArgs = concatStringsSep " " [
    "--model ${whisperModel}"
    "--host ${settings.host}"
    "--port ${settings.port}"
    "--threads ${settings.threads}"
    "--vad" # silero VAD trims silence client-side
    "--vad-model ${vadModel}"
    "-mc 0" # no carry-over context, breaks hallucination chains
    "-sns" # suppress non-speech tokens
    "-nt" # no timestamps in response
  ];

  dictateBin = pkgs.buildGoModule {
    pname = "dictate";
    version = "0.1.0";
    src = ./scripts/dictate;
    vendorHash = null;
    meta.mainProgram = "dictate";
  };

  dictate = pkgs.symlinkJoin {
    name = "dictate";
    paths = [ dictateBin ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/dictate \
        --prefix PATH : ${
          makeBinPath [
            pkgs.pulseaudio # parecord
            pkgs.wtype # type into focused window
            pkgs.wl-clipboard # wl-copy clipboard fallback
            pkgs.libnotify # notify-send lifecycle
          ]
        }
    '';
  };

in
{
  options.modules.stt = {
    enable = mkEnableOption "whisper.cpp STT daemon + dictate hotkey helper";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ dictate ];

    systemd.user.services.whisper-server = {
      description = "whisper.cpp STT HTTP daemon (model kept warm in memory)";
      wantedBy = [ "default.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.whisper-cpp}/bin/whisper-server ${whisperArgs}";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };
  };
}
