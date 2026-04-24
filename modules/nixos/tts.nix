# Piper TTS with a warm-model daemon and a single-hotkey selection reader.
#
# Architecture:
#   • piper-server    — systemd user service, loads the voice model at login
#                       and keeps it warm, exposing piper's HTTP API locally.
#   • speak-selection — the hotkey target. One invocation always stops any
#                       running readout, then captures the current selection
#                       and speaks it if there is one. Shell logic lives in
#                       ./scripts/speak-selection.sh; this file only wires config.
#
# DE-agnostic Wayland: works on GNOME Mutter, Hyprland, Sway, anything that
# speaks the standard wl-clipboard protocol.
#
# Keybind: wire Super+Escape to invoke `speak-selection` in your existing
# GNOME and Hyprland keybinds configs — intentionally NOT managed here.
#
# ydotool group: programs.ydotool.enable creates the "ydotool" group but
# does not add any user to it. Any host with `modules.tts.enable = true`
# must also include "ydotool" in its user's `extraGroups`, otherwise the
# clipboard fallback (synthetic Ctrl+C for browsers / Electron) will fail.
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.modules.tts;

  # ─────────────────────────────────────────────────────────────────────────
  # Settings — everything tunable lives here. Rebuild after changing.
  # ─────────────────────────────────────────────────────────────────────────
  settings = {
    # Voice model. Browse voices at https://huggingface.co/rhasspy/piper-voices
    # After switching voices, replace the two sha256 hashes below.
    voiceName    = "en_US-lessac-high";
    voiceBaseUrl = "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/lessac/high";
    voiceOnnxSha = "02cyrp5xsr5pr4y892i270zzxm1j4191c5aaycvp209qlv1zgasc";
    voiceJsonSha = "0bs1j8d97v6bsvfp82h50a23kckz1scfvf312ny5gwjrk1yvjhnv";

    # Daemon.
    host = "127.0.0.1";
    port = "5174";

    # Synthesis defaults, applied server-side — single source of truth.
    lengthScale     = "0.85";   # <1 speaks faster, >1 slower
    noiseScale      = "0.667";
    noiseWScale     = "0.8";
    sentenceSilence = "0.2";    # seconds of silence between sentences

    # Set to true on machines with a CUDA GPU for hardware synthesis.
    useCuda = false;

    # Client-side behaviour.
    selectionSleep = "0.08";    # seconds to wait after the synthetic Ctrl+C
    maxChars       = "50000";   # hard cap on chars sent to the synthesizer
  };

  # ─────────────────────────────────────────────────────────────────────────
  # Voice model — fetched once into the Nix store.
  # ─────────────────────────────────────────────────────────────────────────
  voiceOnnx = pkgs.fetchurl {
    url    = "${settings.voiceBaseUrl}/${settings.voiceName}.onnx";
    sha256 = settings.voiceOnnxSha;
  };

  voiceJson = pkgs.fetchurl {
    url    = "${settings.voiceBaseUrl}/${settings.voiceName}.onnx.json";
    sha256 = settings.voiceJsonSha;
  };

  voice = pkgs.runCommand "piper-voice-${settings.voiceName}" { } ''
    mkdir -p $out
    cp ${voiceOnnx} $out/${settings.voiceName}.onnx
    cp ${voiceJson} $out/${settings.voiceName}.onnx.json
  '';

  # ─────────────────────────────────────────────────────────────────────────
  # piper-server derivation.
  # piper-tts only ships a one-shot CLI; we re-derive the Python wrapper
  # with piper.http_server as the entry point so the model stays warm.
  # Fragile-ish: depends on piper-tts's generated bin/.piper-wrapped being a
  # Python invocation we can sed. If a nixpkgs bump changes the wrapper
  # shape, inspect `${pkgs.piper-tts}/bin/.piper-wrapped` and adjust.
  # ─────────────────────────────────────────────────────────────────────────
  piperServer = pkgs.runCommand "piper-server" { } ''
    mkdir -p $out/bin
    sed 's|from piper\.__main__ import main|from piper.http_server import main|' \
      ${pkgs.piper-tts}/bin/.piper-wrapped > $out/bin/.piper-server-wrapped
    chmod +x $out/bin/.piper-server-wrapped
    sed "s|${pkgs.piper-tts}/bin/.piper-wrapped|$out/bin/.piper-server-wrapped|g" \
      ${pkgs.piper-tts}/bin/piper > $out/bin/piper-server
    chmod +x $out/bin/piper-server
  '';

  piperArgs = concatStringsSep " " ([
    "-m ${voice}/${settings.voiceName}.onnx"
    "--host ${settings.host}"
    "--port ${settings.port}"
    "--length-scale ${settings.lengthScale}"
    "--noise-scale ${settings.noiseScale}"
    "--noise-w-scale ${settings.noiseWScale}"
    "--sentence-silence ${settings.sentenceSilence}"
  ] ++ optional settings.useCuda "--cuda");

  # ─────────────────────────────────────────────────────────────────────────
  # speak-selection client.
  # Nix provides the config preamble; the shell logic is a separate file.
  # ─────────────────────────────────────────────────────────────────────────
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
      alsa-utils
      curl
      jq
      util-linux     # setsid, flock
      wl-clipboard
      ydotool
    ];
    text = settingsPreamble + "\n" + builtins.readFile ./scripts/speak-selection.sh;
  };
in {
  options.modules.tts = {
    enable = mkEnableOption "Piper TTS daemon + speak-selection hotkey helper";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ speakSelection ];

    # Provides ydotoold (system service) + ydotool client. Creates the
    # "ydotool" group — users need membership (see header comment).
    programs.ydotool.enable = true;

    systemd.user.services.piper-server = {
      description = "Piper TTS HTTP daemon (voice model kept warm in memory)";
      wantedBy    = [ "default.target" ];
      serviceConfig = {
        ExecStart  = "${piperServer}/bin/piper-server ${piperArgs}";
        Restart    = "on-failure";
        RestartSec = 5;
      };
    };
  };
}
