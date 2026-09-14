{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    mkEnableOption
    mkOption
    mkIf
    types
    concatStringsSep
    makeBinPath
    ;
  cfg = config.modules.stt;

  settings = {
    vadModelUrl = "https://huggingface.co/ggml-org/whisper-vad/resolve/main/ggml-silero-v5.1.2.bin";
    vadModelHash = "sha256-KZQNmNQrkfvQXOSJ8+z3xy8KQvAn5IdZGaKPtMBOos8=";

    host = "127.0.0.1";
    port = "5175";
    maxContext = "224"; # zero here silently drops the vocabulary prompt along with the carried context
    vocabulary = "NixOS, nixpkgs, flake, home-manager, Hyprland, systemd, whisper, piper, lessac, keybinds, RAPL, sysfs.";
  };

  engines = {
    whisper-small = {
      url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en.bin";
      hash = "sha256-xhONbVjsyDIgl+D5h8MvG+i7ChhTKj+I9zTRu/nEHl0=";
    };
  };

  whisperModel = pkgs.fetchurl {
    inherit (engines.${cfg.engine}) url hash;
  };
  vadModel = pkgs.fetchurl {
    url = settings.vadModelUrl;
    hash = settings.vadModelHash;
  };

  whisperArgs = concatStringsSep " " [
    "--model ${whisperModel}"
    "--host ${settings.host}"
    "--port ${settings.port}"
    "--threads ${toString cfg.threads}"
    "--vad" # silero VAD trims silence client-side
    "--vad-model ${vadModel}"
    "-mc ${settings.maxContext}"
    "--prompt '${settings.vocabulary}'" # teaches the model this repo's proper nouns
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
            pkgs.libnotify # notify-send for failure popups
            pkgs.procps # pkill to nudge waybar on state change
          ]
        }
    '';
  };

in
{
  options.modules.stt = {
    enable = mkEnableOption "local STT daemon + dictate helper";

    engine = mkOption {
      type = types.enum (builtins.attrNames engines);
      description = "Which speech engine and model size to run. No default: the right one depends on the machine.";
    };

    threads = mkOption {
      type = types.ints.positive;
      description = "Decoder threads. A fanless 2c/4t part wants 2; hyperthreading hurts more than it helps there.";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ dictate ];

    systemd.user.tmpfiles.rules = [
      "d  %S/dictate  0700  -  -  -  -"
      "e  %S/dictate  -     -  -  3d  -"
    ];

    systemd.user.services.whisper-server = {
      description = "whisper.cpp STT HTTP daemon, encoder on the iGPU, model kept warm";
      wantedBy = [ "default.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.whisper-cpp-vulkan}/bin/whisper-server ${whisperArgs}";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };
  };
}
