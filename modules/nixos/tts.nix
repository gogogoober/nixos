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
    maxChars = "10000"; # hard cap on chars sent to synth
    maxChunkChars = "200"; # per-chunk cap inside the streaming pipeline
    codeFenceReplacement = "Code Example.";
    logDir = "%S/speak-selection"; # tmpfiles specifier; resolves to $XDG_STATE_HOME/speak-selection
    logRetentionDays = "2";
  };

  # Sanitization rules. Rendered as four parallel bash arrays (no delimiter).
  # Multi-byte rules are written as exact UTF-8 byte sequences; sanitize_text
  # runs every sed/awk invocation under LC_ALL=C so the patterns match bytes.
  sanitizeRules = [
    # Multi-line block — must run first
    {
      name = "code-fence";
      engine = "awk";
      pattern = "";
      replacement = settings.codeFenceReplacement;
    }

    # Zero-width chars and BOM (individual UTF-8 sequences)
    {
      name = "zwsp";
      engine = "sed";
      pattern = "\\xe2\\x80\\x8b";
      replacement = "";
    }
    {
      name = "zwnj";
      engine = "sed";
      pattern = "\\xe2\\x80\\x8c";
      replacement = "";
    }
    {
      name = "zwj";
      engine = "sed";
      pattern = "\\xe2\\x80\\x8d";
      replacement = "";
    }
    {
      name = "bom";
      engine = "sed";
      pattern = "\\xef\\xbb\\xbf";
      replacement = "";
    }

    # Emoji — byte-range classes work under LC_ALL=C
    {
      name = "emoji-smp";
      engine = "sed";
      pattern = "\\xf0\\x9f[\\x80-\\xbf][\\x80-\\xbf]";
      replacement = "";
    }
    {
      name = "emoji-misc-sym";
      engine = "sed";
      pattern = "\\xe2[\\x98-\\x9e][\\x80-\\xbf]";
      replacement = "";
    }
    {
      name = "emoji-var-sel";
      engine = "sed";
      pattern = "\\xef\\xb8\\x8f";
      replacement = "";
    }

    # Em-dash as exact byte sequence
    {
      name = "em-dash";
      engine = "sed";
      pattern = "\\xe2\\x80\\x94";
      replacement = ", ";
    }

    # Smart quotes — each sequence as its own rule
    {
      name = "sq-left-double";
      engine = "sed";
      pattern = "\\xe2\\x80\\x9c";
      replacement = "\"";
    }
    {
      name = "sq-right-double";
      engine = "sed";
      pattern = "\\xe2\\x80\\x9d";
      replacement = "\"";
    }
    {
      name = "sq-left-single";
      engine = "sed";
      pattern = "\\xe2\\x80\\x98";
      replacement = "'";
    }
    {
      name = "sq-right-single";
      engine = "sed";
      pattern = "\\xe2\\x80\\x99";
      replacement = "'";
    }

    # ASCII-only rules (locale-independent)
    {
      name = "md-emphasis-asterisk";
      engine = "sed";
      pattern = "\\*+([^*]+)\\*+";
      replacement = "\\1";
    }
    {
      name = "md-emphasis-underscore";
      engine = "sed";
      pattern = "_+([^_]+)_+";
      replacement = "\\1";
    }
    {
      name = "md-heading-hash";
      engine = "sed";
      pattern = "^#+[[:space:]]+";
      replacement = "";
    }
    {
      name = "md-blockquote";
      engine = "sed";
      pattern = "^>[[:space:]]+";
      replacement = "";
    }
    {
      name = "url-path-collapse";
      engine = "sed";
      pattern = "https?://([^/[:space:]]+)[^[:space:]]*";
      replacement = "\\1";
    }

    # Must run last
    {
      name = "collapse-whitespace";
      engine = "sed";
      pattern = "[[:space:]]+";
      replacement = " ";
    }
  ];

  renderSanitizeRules =
    let
      render = field: concatMapStringsSep " " (r: escapeShellArg r.${field}) sanitizeRules;
    in
    ''
      SANITIZE_NAMES=( ${render "name"} )
      SANITIZE_ENGINES=( ${render "engine"} )
      SANITIZE_PATTERNS=( ${render "pattern"} )
      SANITIZE_REPLACEMENTS=( ${render "replacement"} )
    '';

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
    MAX_CHUNK_CHARS="${settings.maxChunkChars}"
    LOCK_FILE="''${XDG_RUNTIME_DIR:-/tmp}/speak-selection.pgid"
    MAIN_LOCK="''${XDG_RUNTIME_DIR:-/tmp}/speak-selection.main.lock"
    LOG_DIR="''${XDG_STATE_HOME:-$HOME/.local/state}/speak-selection"
    LOGGING_ENABLED="${boolToString cfg.loggingEnabled}"
    NOTIFICATIONS_ENABLED="${boolToString cfg.notificationsEnabled}"
    ${renderSanitizeRules}
  '';

  speakSelection = pkgs.writeShellApplication {
    name = "speak-selection";
    runtimeInputs = with pkgs; [
      alsa-utils # aplay / wav playback
      curl # HTTP client to piper-server
      jq # JSON parser
      libnotify # notify-send for sendNotification
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
    devMode = mkOption {
      type = types.bool;
      default = false;
      description = "Master toggle for development-time features. Sets the default for loggingEnabled and notificationsEnabled; each can be overridden individually.";
    };
    loggingEnabled = mkOption {
      type = types.bool;
      default = cfg.devMode;
      description = "Write debug events to the daily log file under $XDG_STATE_HOME/speak-selection/.";
    };
    notificationsEnabled = mkOption {
      type = types.bool;
      default = cfg.devMode;
      description = "Emit lifecycle notifications via sendNotification. Errors bypass this gate.";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ speakSelection ];

    systemd.user.tmpfiles.rules = [
      "d  ${settings.logDir}  0700  -  -  -  -"
      "e  ${settings.logDir}  -     -  -  ${settings.logRetentionDays}d  -"
    ];

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
