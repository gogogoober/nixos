# Speech-to-Text PRD

## Goal
Mirror the existing TTS module so the system gains the inverse capability:
press one hotkey to start dictating, press again to stop, and have the
spoken text typed into whichever window has focus. Fully local, no
network calls, no browser involvement. Reuse the press-toggle ergonomics,
the local-HTTP-daemon shape, and the dual-DE keybind pattern already
proven in `tts.nix`.

## Current State

### Module: `modules/nixos/stt.nix`
A stub. Exposes `modules.stt.enable` and installs nothing. Both hosts
already opt in (`hosts/dell-old/default.nix:29` and
`hosts/surface-go-3/default.nix:25`), so flipping the switch on the
real implementation needs no host edits.

### Module: `modules/nixos/tts.nix` (parallel reference)
The shape we're cloning:

- A pinned voice model fetched via `pkgs.fetchurl` with explicit sha256
- A `systemd.user.services.piper-server` that keeps the model warm
- A `pkgs.writeShellApplication` wrapping a script in
  `modules/nixos/scripts/speak-selection.sh`
- A press-toggle state machine using two lock files in
  `$XDG_RUNTIME_DIR`: a main flock to debounce keyboard autorepeat and
  a pgid lock so a second press can kill the first
- `programs.ydotool.enable` for synthetic keypresses

### Existing keybind wiring
- Hyprland: `modules/home-manager/hyprland/keybinds.nix:81` binds
  `SUPER + escape` to `speak-selection`
- GNOME: `modules/home-manager/desktop.nix:88-104` registers a single
  custom-keybinding entry for the same shortcut via dconf
- Both DEs need parallel updates per the universal-keybinds rule

### Audio stack
PipeWire is the system audio server (default for the desktop module).
`parecord` from `pulseaudio` works against PipeWire's pulse shim and
produces the 16 kHz mono WAV that whisper expects.

## References

- **whisper.cpp** (`pkgs.whisper-cpp`) — local Whisper inference. Ships
  a `whisper-server` binary that exposes an HTTP `/inference` endpoint
  taking multipart audio uploads. This is the direct analogue to
  `piper-server` in the TTS module.
- **Whisper ggml models** — `https://huggingface.co/ggerganov/whisper.cpp`.
  Default pin: `ggml-base.en.bin` (~150 MB, English-only, fast on CPU).
  Step-up option if accuracy is short: `ggml-small.en.bin` (~500 MB).
- **wtype** (`pkgs.wtype`) — Wayland-native synthetic typing. Cleaner
  than reusing `ydotool` for this path because we are inserting a string
  rather than synthesizing a single chord; ydotool stays available as a
  fallback since the user is already in its group.
- **parecord** (from `pkgs.pulseaudio`) — records 16 kHz mono WAV from
  the default PipeWire source.

## Proposed Changes

### Replace the stub in `modules/nixos/stt.nix`
Adopt the same structure as `tts.nix`:

- A `settings` attrset at the top with the model name, base URL, sha256,
  daemon host/port (e.g. `127.0.0.1:5175` to sit next to piper on 5174),
  recording sample rate (16000), max recording seconds (e.g. 120 as a
  safety cap), and a press-debounce sleep
- `modelGgml = pkgs.fetchurl { ... }` pinned by sha256
- A `whisperServer` runCommand wrapping `pkgs.whisper-cpp`'s
  `whisper-server` with the model path and host/port baked in
- A `dictate` shell application built with `pkgs.writeShellApplication`,
  pulling in `pulseaudio` (for `parecord`), `curl`, `jq`, `util-linux`
  (for `setsid` and `flock`), and `wtype`
- `systemd.user.services.whisper-server` that keeps the model resident
- `environment.systemPackages = [ dictate ]`

### New script: `modules/nixos/scripts/dictate.sh`
A press-toggle state machine that mirrors `speak-selection.sh`:

- Two lock files in `$XDG_RUNTIME_DIR`: `dictate.main.lock` (flock for
  debounce) and `dictate.recording.pgid` (pgid of the live recorder)
- First press with no recording in flight: spawn a detached `setsid`
  child that runs `parecord` into a temp WAV under `$XDG_RUNTIME_DIR`,
  writes its pgid to the recording lock, and waits
- Second press while recording: read the pgid, send SIGTERM to the
  process group to stop `parecord` cleanly, wait for the temp WAV to
  flush, then `curl` it to `whisper-server`'s `/inference` endpoint with
  `language=en` and `response_format=text`, pipe the result through a
  trim, and feed it to `wtype -` so it lands in the focused window
- The recorder child has its own EXIT trap that removes the pgid lock
  and the temp WAV
- A hard cap on recording duration (kill the recorder after the configured
  seconds) so a stuck press cannot fill the runtime dir

### New hotkey: `Super + grave` (the backtick key)
Adjacent to `Super + escape`, free in both Hyprland and GNOME, and the
ergonomic neighbor pairing reads as "speak / dictate" — Escape reads
selection, grave records dictation.

In `modules/home-manager/hyprland/keybinds.nix`, add a new line in the
`bindd` list right under the TTS binding:

```
"SUPER,      grave,  Dictate,               exec, dictate"
```

In `modules/home-manager/desktop.nix`, extend
`org/gnome/settings-daemon/plugins/media-keys.custom-keybindings` with a
second path and add a matching custom-keybindings/dictate entry binding
`<Super>grave` to `dictate`.

### `wtype` needs to be installed
Add `pkgs.wtype` to `runtimeInputs` of the `dictate` shell application
(not to `environment.systemPackages` — keep it scoped to the helper, the
way `tts.nix` scopes `wl-clipboard` and `ydotool`).

## Target Files
- `modules/nixos/stt.nix` (replace stub with full implementation)
- `modules/nixos/scripts/dictate.sh` (new)
- `modules/home-manager/hyprland/keybinds.nix` (one new line)
- `modules/home-manager/desktop.nix` (extend dconf custom-keybindings)

## Decisions to Confirm

- **Engine:** whisper.cpp over Vosk/nerd-dictation. Whisper is markedly
  more accurate, especially on technical vocabulary, and the
  record-then-transcribe flow fits the press-toggle pattern better than
  Vosk's streaming model. The cost is a one-to-three-second pause
  between stop-press and text appearing on a CPU box.
- **Model:** `ggml-base.en` as the default pin. Bumping to `small.en`
  is a one-line change if base proves too lossy.
- **Hotkey:** `Super + grave`. Alternative is `Super + insert` if
  Surface Go keyboards prove awkward on the backtick row.
- **Typing tool:** `wtype` over `ydotool --type`. ydotool would work but
  adds a daemon hop and feels heavier than needed for plain text.

## Status
Not implemented. Stub still in place at `modules/nixos/stt.nix`; both
hosts have `stt.enable = true` waiting for a real config block.
