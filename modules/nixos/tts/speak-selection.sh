# speak-selection.sh — capture the current Wayland selection and read it aloud
# via piper-server. Settings are prepended by tts.nix at build time:
#
#   PIPER_HOST, PIPER_PORT, SELECTION_SLEEP, MAX_CHARS,
#   LOCK_FILE, MAIN_LOCK
#
# Semantics (a single hotkey drives every state):
#   idle + selection    → start reading
#   idle + no selection → no-op
#   reading             → stop, exit (pure toggle — press again to stop)

# ─────────────────────────────────────────────────────────────────────────
# --run subcommand
# Re-entry point spawned by the main flow as a detached session via
# `setsid --fork`. jq, curl, and aplay share this session's pgid, so a
# single `kill -TERM -<pgid>` from a subsequent invocation stops the whole
# pipeline mid-sentence.
# ─────────────────────────────────────────────────────────────────────────
if [ "${1:-}" = "--run" ]; then
  text="${TTS_TEXT:-}"
  unset TTS_TEXT
  [ -n "$text" ] || exit 0

  echo "$$" > "$LOCK_FILE"

  # shellcheck disable=SC2329  # invoked via trap
  cleanup_run() {
    # Only remove the file if it still points at us — a later invocation
    # may have already overwritten it.
    local current
    current="$(cat "$LOCK_FILE" 2>/dev/null || true)"
    if [ "$current" = "$$" ]; then rm -f "$LOCK_FILE"; fi
  }
  trap cleanup_run EXIT

  jq -n --arg t "$text" '{text:$t}' \
    | curl -sS --max-time 300 -X POST \
        -H "Content-Type: application/json" \
        --data-binary @- \
        "http://$PIPER_HOST:$PIPER_PORT/" \
    | aplay -q

  unset text
  exit 0
fi

# ─────────────────────────────────────────────────────────────────────────
# Main flow
# ─────────────────────────────────────────────────────────────────────────

# Block concurrent main flows (e.g. keyboard autorepeat). A rapid second
# press within the ~250ms it takes to capture a selection is ignored — the
# first press's readout will start. Subsequent presses during the readout
# itself acquire the lock normally and perform stop-and-replace.
exec 9> "$MAIN_LOCK"
if ! flock -n 9; then
  exit 0
fi

# 1. If a reader is in flight, stop it and exit — press-again-to-stop.
if [ -f "$LOCK_FILE" ]; then
  old_pgid="$(cat "$LOCK_FILE" 2>/dev/null || true)"
  if [ -n "$old_pgid" ]; then
    kill -TERM "-$old_pgid" 2>/dev/null || true
  fi
  rm -f "$LOCK_FILE"
  unset old_pgid
  exit 0
fi

# 2. Capture the current selection.
# PRIMARY is populated by terminals, editors, and most GTK apps — try it
# first so those paths never trigger the synthetic Ctrl+C.
text="$(wl-paste --primary --no-newline 2>/dev/null || true)"

if [ -z "$text" ]; then
  # Browsers / Electron don't populate PRIMARY. Fall back to the clipboard:
  # save whatever's there, clear it, synth Ctrl+C on the focused app, read
  # the result, then restore. Skipped entirely if the clipboard holds
  # non-text — wl-clipboard can't reliably round-trip binary payloads and
  # silently destroying an image would be worse than not reading.
  #
  # Known caveat: if PRIMARY is empty AND a terminal has focus with a
  # foreground process running, the synthetic Ctrl+C will SIGINT it. There
  # is no way to detect this on GNOME Wayland; avoid pressing the hotkey
  # on a terminal that has no selection.
  clip_types="$(wl-paste --list-types 2>/dev/null || true)"
  case "$clip_types" in
    *image/*|*video/*|*audio/*)
      :  # non-text — leave it alone, no selection
      ;;
    *)
      saved="$(wl-paste --no-newline 2>/dev/null || true)"
      wl-copy --clear 2>/dev/null || true
      # Release any modifier the user may still be physically holding from the
      # hotkey, then synth Ctrl+C. Without this the compositor combines the
      # held modifier with the injected Ctrl+C and any matching binding fires
      # (e.g. Forge's window-snap-center on <Control><Alt>c).
      # 56=LEFTALT 100=RIGHTALT 125=LEFTMETA 126=RIGHTMETA 42=LEFTSHIFT 54=RIGHTSHIFT
      # 29=LEFTCTRL 46=C. Format is keycode:1 down / keycode:0 up.
      ydotool key 56:0 100:0 125:0 126:0 42:0 54:0 29:1 46:1 46:0 29:0 2>/dev/null || true
      sleep "$SELECTION_SLEEP"
      text="$(wl-paste --no-newline 2>/dev/null || true)"
      if [ -n "$saved" ]; then
        printf '%s' "$saved" | wl-copy 2>/dev/null || true
      else
        wl-copy --clear 2>/dev/null || true
      fi
      unset saved
      ;;
  esac
  unset clip_types
fi

# 3. No selection → nothing to read.
if [ -z "$text" ]; then
  exit 0
fi

# 4. Defensive cap. Piper streams sentence-by-sentence so long text is fine,
# but a user who accidentally highlights an entire page probably didn't mean
# to queue 20 minutes of audio.
if [ "${#text}" -gt "$MAX_CHARS" ]; then
  text="${text:0:$MAX_CHARS}"
fi

# 5. Hand off to a detached session. Passing the text via env var keeps it
# out of argv (so it's not visible in /proc/<pid>/cmdline) and avoids ever
# writing it to disk. The env var is only readable by our UID via
# /proc/<pid>/environ, and the --run branch unsets it immediately.
TTS_TEXT="$text" setsid --fork "$0" --run </dev/null >/dev/null 2>&1
unset text TTS_TEXT
