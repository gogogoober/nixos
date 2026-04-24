# One-hotkey state machine: idle+selection starts read, reading stops.
# tts.nix prepends PIPER_HOST, PIPER_PORT, SELECTION_SLEEP, MAX_CHARS, LOCK_FILE, MAIN_LOCK.

DEBUG_LOG="${XDG_RUNTIME_DIR:-/tmp}/speak-selection.debug.log"
log() { printf '[%s] %s pid=%s pgid=%s %s\n' "$(date +%H:%M:%S.%3N)" "${1:-?}" "$$" "$(ps -o pgid= -p $$ | tr -d ' ')" "${2:-}" >> "$DEBUG_LOG"; }

# --run: detached session via setsid --fork; shared pgid lets main kill the pipeline
if [ "${1:-}" = "--run" ]; then
  text="${TTS_TEXT:-}"
  unset TTS_TEXT
  log RUN-enter "text_len=${#text}"
  [ -n "$text" ] || exit 0

  echo "$$" > "$LOCK_FILE"
  log RUN-lockwritten "content=$$"

  # shellcheck disable=SC2329  # invoked via trap
  cleanup_run() {
    # Only remove if still ours
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
  log RUN-finished "aplay exited"

  unset text
  exit 0
fi

# Block concurrent main flows (keyboard autorepeat)
log MAIN-enter "args=$*"
exec 9> "$MAIN_LOCK"
if ! flock -n 9; then
  log MAIN-flock-failed "another main flow is already running"
  exit 0
fi
log MAIN-flock-acquired ""

# 1. Reader in flight → stop and exit (press-again-to-stop)
if [ -f "$LOCK_FILE" ]; then
  old_pgid="$(cat "$LOCK_FILE" 2>/dev/null || true)"
  log MAIN-stopping "old_pgid=$old_pgid"
  if [ -n "$old_pgid" ]; then
    kill -TERM "-$old_pgid" 2>/dev/null || true
  fi
  rm -f "$LOCK_FILE"
  unset old_pgid
  exit 0
fi
log MAIN-no-reader "LOCK_FILE absent"

# 2. Capture selection. PRIMARY covers terminals/editors/GTK; try it first to skip synth Ctrl+C
text="$(wl-paste --primary --no-newline 2>/dev/null || true)"

if [ -z "$text" ]; then
  # Browsers/Electron need synth Ctrl+C: save clip, clear, synth, read, restore.
  # Skip non-text — wl-clipboard can't round-trip binary safely.
  # Caveat: in a terminal with no selection, synth Ctrl+C will SIGINT the foreground process.
  clip_types="$(wl-paste --list-types 2>/dev/null || true)"
  case "$clip_types" in
    *image/*|*video/*|*audio/*)
      :
      ;;
    *)
      saved="$(wl-paste --no-newline 2>/dev/null || true)"
      wl-copy --clear 2>/dev/null || true
      # Release held modifiers first, else compositor fires their bound action
      # 56=LEFTALT 100=RIGHTALT 125=LEFTMETA 126=RIGHTMETA 42=LEFTSHIFT 54=RIGHTSHIFT 29=LEFTCTRL 46=C
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

if [ -z "$text" ]; then
  exit 0
fi

# 3. Cap to avoid queuing 20 minutes of audio on accidental whole-page selections
if [ "${#text}" -gt "$MAX_CHARS" ]; then
  text="${text:0:$MAX_CHARS}"
fi

# 4. Hand off. Env var keeps text out of argv / /proc/<pid>/cmdline
log MAIN-spawning "text_len=${#text}"
# Close fd 9 so detached reader doesn't inherit MAIN_LOCK flock
TTS_TEXT="$text" setsid --fork "$0" --run </dev/null >/dev/null 2>&1 9<&-
log MAIN-spawned ""
unset text TTS_TEXT
