# One-hotkey state machine: idle+selection starts read, reading stops.
# tts.nix prepends PIPER_HOST, PIPER_PORT, SELECTION_SLEEP, MAX_CHARS, LOCK_FILE,
# MAIN_LOCK, MAX_CHUNK_CHARS, LOG_DIR, LOGGING_ENABLED, NOTIFICATIONS_ENABLED,
# and the SANITIZE_* parallel arrays.

mkdir -p "$LOG_DIR" 2>/dev/null || true
DEBUG_LOG="$LOG_DIR/speak-selection-$(date -u +%F).log"

log() {
  [ "${LOGGING_ENABLED:-false}" = "true" ] || return 0
  printf '[%s] %s pid=%s pgid=%s %s\n' \
    "$(date +%H:%M:%S.%3N)" "${1:-?}" "$$" \
    "$(ps -o pgid= -p $$ | tr -d ' ')" "${2:-}" >> "$DEBUG_LOG"
}

sendNotification() {
  local label="$1"
  local is_error="${2:-false}"
  if [ "$is_error" = "true" ]; then
    timeout 1 notify-send -t 3000 -u critical -a speak-selection "$label" 2>/dev/null || true
    return 0
  fi
  [ "${NOTIFICATIONS_ENABLED:-false}" = "true" ] || return 0
  timeout 1 notify-send -t 1500 -a speak-selection "$label" 2>/dev/null || true
}

sanitize_text() {
  local buf="$1" i n engine pattern replacement
  n="${#SANITIZE_NAMES[@]}"
  for (( i=0; i<n; i++ )); do
    engine="${SANITIZE_ENGINES[$i]}"
    pattern="${SANITIZE_PATTERNS[$i]}"
    replacement="${SANITIZE_REPLACEMENTS[$i]}"
    case "$engine" in
      awk)
        # Split on ``` fences; odd records are prose (kept), even are code (replaced).
        buf="$(printf '%s' "$buf" | LC_ALL=C awk -v rep="$replacement" '
          BEGIN { RS = "```"; ORS = "" }
          { if (NR % 2 == 1) print $0; else print rep }
        ')"
        ;;
      sed)
        # shellcheck disable=SC2001
        buf="$(printf '%s' "$buf" | LC_ALL=C sed -E "s|${pattern}|${replacement}|g")"
        ;;
    esac
  done
  printf '%s' "$buf"
}

split_into_chunks() {
  awk -v cap="$MAX_CHUNK_CHARS" '
    BEGIN { buf = "" }
    {
      n = split($0, words, " ")
      for (i = 1; i <= n; i++) {
        if (words[i] == "") continue
        candidate = (buf == "" ? words[i] : buf " " words[i])
        if (length(candidate) > cap && buf != "") {
          print buf " "
          buf = words[i]
        } else {
          buf = candidate
        }
        if (match(buf, /[.!?,]$/) && length(buf) >= 40) {
          print buf " "
          buf = ""
        }
      }
    }
    END { if (buf != "") print buf " " }
  '
}

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

  text="$(sanitize_text "$text")"
  log SANITIZE-stats "len=${#text}"
  log SANITIZE-output "$text"

  if [ -z "${text// }" ]; then
    log SANITIZE-empty ""
    exit 0
  fi

  sendNotification processing-start

  printf '%s' "$text" \
    | split_into_chunks \
    | while IFS= read -r chunk; do
        if [ -z "${chunk// }" ]; then
          log CHUNK-skip-empty ""
          continue
        fi
        log CHUNK-emit "len=${#chunk} text=${chunk}"
        if ! jq -n --arg t "$chunk" '{text:$t}' \
             | curl -sS --max-time 60 --fail -X POST \
                 -H 'Content-Type: application/json' --data-binary @- \
                 "http://$PIPER_HOST:$PIPER_PORT/" \
             | tail -c +45; then
          log SYNTH-error "chunk_failed"
          sendNotification synth-error true
          exit 1
        fi
      done \
    | aplay -q -f S16_LE -r 22050 -c 1
  status=$?

  if [ "$status" -eq 0 ]; then
    log PIPELINE-finished ""
    sendNotification processing-end
  fi

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
  sendNotification cancelled
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
  log SELECTION-truncated "from=${#text} to=$MAX_CHARS"
  sendNotification "Over max character count" true
  text="${text:0:$MAX_CHARS}"
fi

# 4. Hand off. Env var keeps text out of argv / /proc/<pid>/cmdline
log MAIN-spawning "text_len=${#text}"
# Close fd 9 so detached reader doesn't inherit MAIN_LOCK flock
TTS_TEXT="$text" setsid --fork "$0" --run </dev/null >/dev/null 2>&1 9<&-
log MAIN-spawned ""
unset text TTS_TEXT
