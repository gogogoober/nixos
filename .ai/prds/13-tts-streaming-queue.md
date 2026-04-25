# TTS Streaming Queue PRD

## Goal
Cut the time-to-first-audio on long selections so playback starts within a
sentence or two of the press, regardless of how much text was selected.
Replace the single-shot synthesis (one POST of the full payload to
piper-server) with a chunked pipeline: split text into sentences,
sanitize them, synthesize each in order, and stream the resulting audio
to a single playback process. Preserve the existing press-again-to-stop
behavior — second hotkey press must cancel synthesis and audio together,
mid-sentence if needed.

## Current State

### Module: `modules/nixos/tts.nix`
Wires up `piper-server` as a systemd user service, builds the
`speak-selection` shell application, and registers the keybind. None of
this needs to change — the daemon is already a long-lived warm process,
which is exactly what a streaming pipeline wants.

### Script: `modules/nixos/scripts/speak-selection.sh`
The whole pipeline today is one line:

```
jq -n --arg t "$text" '{text:$t}' \
  | curl ... "http://$PIPER_HOST:$PIPER_PORT/" \
  | aplay -q
```

piper-server synthesizes the entire payload before the WAV header is
finalized, so `aplay` blocks until the whole thing is generated. On a
3000-character selection that's a multi-second wait before any sound.

The press-toggle state machine sits *around* that one-liner and is
healthy as-is: a `MAIN_LOCK` flock debounces keyboard autorepeat, and a
`LOCK_FILE` holds the detached child's PGID so a second press can
SIGTERM the whole process group. Anything we add must inherit that PGID
so cancellation still works.

### Output format
piper-server returns WAV: 16-bit mono PCM at 22050 Hz. Confirmed by
probing the running daemon. Sample rate matters for the playback path
below.

### Selection capture and char cap
Lines 60-98 of `speak-selection.sh` already handle clipboard capture and
the 50000-char hard cap. Both stay untouched — sanitization runs on the
text *after* capture, before chunking.

## References

- **piper-server endpoint:** `POST http://127.0.0.1:5174/` with
  `{"text": "..."}` returns `audio/wav` (RIFF, 16-bit PCM, mono,
  22050 Hz).
- **Existing pipeline:** `modules/nixos/scripts/speak-selection.sh:26-31`
- **Piper voice model:** pinned in `modules/nixos/tts.nix:13-17`
- **Process-group cancellation:** `modules/nixos/scripts/speak-selection.sh:48-57`
- **Sentence segmentation prior art:** the Unix tool `fmt` is too crude
  here; a small awk or sed sentence splitter handles
  `. ? ! ; \n\n` boundaries with abbreviation guards (Mr., Dr., e.g.,
  i.e., U.S., etc.).

## Proposed Changes

### Sanitization stage
A `sanitize_text` shell function runs once on the captured text before
any chunking. It removes characters that confuse piper or generate
audible artifacts while preserving anything that affects prosody
(commas, periods, question marks).

The rules are defined declaratively as a table of pattern → replacement
pairs in `tts.nix`, not as a procedural chain of sed invocations in the
script. The Nix module renders the table into a sourced shell array
that the script iterates. Adding or removing a rule means editing the
attrset, not editing the script.

```nix
sanitizeRules = [
  { name = "zero-width";        pattern = "[\\u200B-\\u200D\\uFEFF]"; replacement = "";              }
  { name = "emoji";              pattern = "<emoji-class>";            replacement = "";              }
  { name = "code-fence";         pattern = "```[\\s\\S]*?```";        replacement = "Code Example."; }
  { name = "url-path-collapse";  pattern = "https?://([^/\\s]+)\\S*"; replacement = "\\1";           }
  { name = "em-dash";             pattern = "—";                        replacement = ", ";            }
  { name = "smart-quotes";        pattern = "[“”]";          replacement = "\"";            }
  { name = "smart-apostrophes";   pattern = "[‘’]";          replacement = "'";             }
  { name = "md-emphasis-asterisk";pattern = "\\*+([^*]+)\\*+";         replacement = "\\1";           }
  { name = "md-emphasis-underscore"; pattern = "_+([^_]+)_+";          replacement = "\\1";           }
  { name = "md-heading-hash";     pattern = "^#+\\s+";                  replacement = "";              }
  { name = "md-blockquote";       pattern = "^>\\s+";                   replacement = "";              }
  { name = "collapse-whitespace"; pattern = "[ \\t]+";                  replacement = " ";             }
];
```

Each rule is applied in order. The script's `sanitize_text` is a
small loop that walks the array and pipes the buffer through `sed -E`
once per rule — readable, testable, and the rule order is data, not
control flow. Engine choice (sed vs awk) is per-rule and lives in the
attrset alongside the pattern.

### Empty-after-sanitization handling
Two guards, defined as named early-return checks:

1. **Pre-flight bail.** After capture and sanitization, if the result
   is empty or whitespace-only, the script exits cleanly with no
   audio, no spawn, no piper request. The detached `--run` child is
   never started. This is the "user selected only emoji and code
   fences" case — graceful no-op, no clicks, no error.
2. **Per-chunk skip.** Inside the streaming loop, each chunk is
   re-checked after the chunker emits it. An empty chunk (which
   shouldn't happen post-sanitize but could in principle) is skipped
   silently rather than POSTed to piper. One named guard, one
   `continue`, no nested branching.

Both checks run on the post-sanitize buffer, so any rule in the table
above can drop content to nothing without breaking the pipeline.

### Sentence chunking stage
A function `split_into_chunks` reads the sanitized text and emits one
chunk per line on stdout. The rule, in order of priority:

1. **End at a sentence boundary if reachable within the char cap.**
   Boundaries are `.`, `?`, `!`, or a blank line, with the usual
   abbreviation guards (`Mr.`, `Mrs.`, `Dr.`, `Sr.`, `Jr.`, `St.`,
   `vs.`, `e.g.`, `i.e.`, `U.S.`, single-letter initials, decimal
   numbers, ellipses).
2. **Otherwise end at the last space before the 200-char cap.**
   Splitting mid-word would butcher pronunciation, so the chunker
   walks back from the cap to the nearest space and emits everything
   up to it.
3. **Or end of selection**, whichever of the above comes first.

So the typical chunk is one sentence. A short sentence is emitted as
itself; a sentence longer than 200 characters is emitted as
successive ~200-char fragments that each end on a word boundary; the
final chunk is whatever's left of the selection.

**Forced trailing space.** Every chunk emitted to the synth loop has
exactly one trailing space appended before being JSON-encoded and
sent to piper. This guarantees a small tail of silence in the
rendered WAV, which matters most for word-boundary splits that have
no terminal punctuation — without the trailing space the audio cuts
off the instant the last phoneme finishes and the next chunk's audio
butts directly against it, making mid-sentence boundaries sound
rushed or run-together. Sentence-ending chunks also benefit: piper's
`sentenceSilence` setting inserts a pause *inside* a request between
sentences, but does nothing at the very end of a request, so the
trailing space provides that final beat of breathing room. The
chunker normalizes any existing trailing whitespace first so we
always send exactly one space, never two.

This drops the dynamic mean-sentence-length math from an earlier draft
in favor of a fixed cap. The fixed cap is easier to reason about, has
no degenerate-input edge case, and 200 characters is short enough
that first-audio latency stays low even on a sentence-less wall of
text.

Implementation: a single awk pass. Runs in single-digit milliseconds
on any selection that fits the existing 50000-char hard cap.

### Streaming pipeline
The detached `--run` branch of `speak-selection.sh` runs a single
producer process that pipes raw PCM directly into one long-lived
`aplay`. No temp files, no filesystem queue, no scheduling math.

```
split_into_chunks "$text" \
  | while IFS= read -r chunk; do
      jq -n --arg t "$chunk" '{text:$t}' \
        | curl -sS --max-time 60 -X POST \
            -H 'Content-Type: application/json' --data-binary @- \
            "http://$PIPER_HOST:$PIPER_PORT/" \
        | tail -c +45                # strip 44-byte WAV header
    done \
  | aplay -q -f S16_LE -r 22050 -c 1
```

Why this works:

- **Piper is single-instance**, so synthesis is naturally serial.
  There is nothing to gain from parallelism, which is what a queue
  would have unlocked. A queue solves a problem we don't have.
- **The kernel pipe buffer plus ALSA's audio buffer give us the
  synth-ahead behavior for free.** Once aplay's buffer fills, the
  producer's `tail -c` write blocks until aplay drains, and synth
  naturally stays one to two chunks ahead.
- **Header stripping is required** because piper returns a complete
  WAV per request (44-byte RIFF header + PCM). Concatenating those
  raw would confuse aplay; stripping the header on every chunk
  yields a clean PCM stream. The format flags on aplay
  (`-f S16_LE -r 22050 -c 1`) match the pinned voice's output.
- **Time-to-first-audio is the synthesis time of one short chunk**,
  not the whole selection. That's the entire point of this PRD and
  it falls out of the design rather than being engineered in.
- **EOF closes the pipeline.** When `split_into_chunks` exhausts the
  input, the loop ends, the pipe closes, aplay sees EOF, drains its
  buffer, and exits. No end-of-stream flag, no inotify watch, no
  cleanup trap beyond what already exists.
- **Cancellation is unchanged.** The whole pipeline runs under the
  same `setsid` PGID. Second-press still SIGTERMs the process group
  and the existing lock-file logic still applies.

### Underrun behavior
If a chunk takes longer to synthesize than the previous chunk takes
to play, ALSA's buffer drains and you hear a brief gap. The buffer
is roughly one to two seconds at piper's 22050 Hz mono — large enough
that synth-faster-than-realtime keeps it full, small enough that
recovery is immediate when synth catches up. The 200-char chunk cap
keeps any single chunk's synth time bounded, which keeps underruns
rare.

### Synth error handling
On a non-200 response from piper, a curl timeout, or any other synth
failure inside the chunk loop, the pipeline aborts: the loop breaks
out, `sendNotification "synth-error" true` fires (forced through the
gate), `log SYNTH-error` records the chunk number and curl exit code
or HTTP status, the producer subshell exits, the pipe closes, aplay
drains whatever audio was already buffered, and everything tears down
through the existing PGID cleanup path. The user can press the
hotkey again to retry. No skip-and-continue — a daemon failure on
chunk five usually means chunk six will fail the same way, and
silently jumping over content is worse than a clean stop with a
visible signal.

### Bounded queue
Not needed in the streaming-pipe design. Backpressure happens
naturally: the producer's `tail -c +45` blocks on write once the
kernel pipe buffer plus aplay's ALSA buffer are full, so synthesis
can never run more than a couple of chunks ahead of playback. No
explicit cap, no sleep loop, no count of pending files.

### Settings exposed in `tts.nix`
Two layers. The internal `settings` attrset gains a few module-private
constants, and `options.modules.tts` gains user-facing toggles for
development-time behavior.

Internal `settings` (module-private constants):

- `maxChunkChars = "200";`
- `stripEmoji = true;`
- `codeFenceReplacement = "Code Example.";`
- `logDir = "%S/speak-selection";` # systemd-tmpfiles specifier; resolves to $XDG_STATE_HOME/speak-selection at runtime
- `logRetentionDays = "2";`

User-facing options under `options.modules.tts`:

- `devMode` — bool, default `false`. Master toggle for
  development-time behavior. Sets the *default* for every
  finer-grained dev flag below; each flag can still be overridden
  individually.
- `loggingEnabled` — bool, default `cfg.devMode`. Controls whether
  the `log()` function actually writes to the daily log file. When
  off, `log()` is a no-op.
- `notificationsEnabled` — bool, default `cfg.devMode`. Controls
  whether `sendNotification()` actually fires.

The pattern is intentionally extensible: any future dev-only feature
gets its own `<feature>Enabled` option that defaults to `cfg.devMode`,
so flipping the master switch lights everything up while still
allowing programmatic per-feature control. Hosts that want everything
off (the production default) leave `devMode = false`. Hosts that want
notifications without log noise can set
`devMode = false; notificationsEnabled = true;`.

All of these flow into the script via the existing `settingsPreamble`
mechanism, same shape as the current `MAX_CHARS` and `SELECTION_SLEEP`,
exported as shell vars (`LOGGING_ENABLED`, `NOTIFICATIONS_ENABLED`).

### Logging and retention
The existing `log()` function and `DEBUG_LOG` variable stay, but the
log location moves out of `$XDG_RUNTIME_DIR` (which is wiped on
session end) and into `$XDG_STATE_HOME/speak-selection/`, which is
the canonical XDG path for "persistent state we don't need to keep
forever." The script writes one log file per UTC day,
`speak-selection-YYYY-MM-DD.log`, so age-based cleanup is a trivial
file-mtime operation rather than a log-rotation dance.

New events the pipeline logs, on top of the existing MAIN/RUN events:

- `SANITIZE-stats` — input length, output length, names of rules that
  fired (one log line per press)
- `SANITIZE-empty` — pre-flight bail because sanitization emptied the
  buffer (no spawn, no synth)
- `CHUNK-emit` — chunk number, char count, ends-on-sentence vs
  ends-on-word-boundary
- `CHUNK-skip-empty` — per-chunk empty skip inside the loop (should
  be rare; logged so it's noticeable if it stops being rare)
- `SYNTH-error` — non-200 from piper, curl exit code, chunk number
- `PIPELINE-finished` — total chunks, total seconds elapsed (clean
  exits only; cancellations are already logged via the existing trap
  path)

Retention is declarative, defined in the Nix module rather than the
script:

```nix
systemd.user.tmpfiles.rules = [
  "d  ${settings.logDir}  0700  -  -  -  -"
  "e  ${settings.logDir}  -     -  -  ${settings.logRetentionDays}d  -"
];
```

The first line ensures the directory exists with private permissions
on first user-session start. The second line cleans regular files
older than the configured age every time systemd-tmpfiles runs, which
is at boot, on user-session start, and on a daily timer. No shell
`find` invocation, no ExecStartPre on the piper-server unit, no
script-level cleanup logic — the system handles it as a tmpfiles
rule. If you ever want to bump retention to 7 days or drop it to a
single day, you change one number in `settings`.

The `log()` function gates on `LOGGING_ENABLED` first thing — if the
flag is off, the function returns immediately and the log file is
never opened. The gate is absolute: it covers the new
SANITIZE/CHUNK/SYNTH/PIPELINE events *and* the existing
MAIN/RUN events from the press-toggle state machine. Every event in
the script goes through `log()` rather than touching the file
directly, so respecting the flag is a single guard rather than a
scattering of if-blocks. With `loggingEnabled = false`, no key press
ever writes to disk.

### Notifications via `sendNotification`
A new shell function in `speak-selection.sh` is the single point
through which all lifecycle markers flow. Contract: takes a label
string and an optional error flag, returns 0, never blocks.

```sh
sendNotification() {
  local label="$1"
  local is_error="${2:-false}"
  if [ "$is_error" = "true" ]; then
    notify-send -t 3000 -u critical -a speak-selection "$label" 2>/dev/null || true
    return 0
  fi
  [ "$NOTIFICATIONS_ENABLED" = "true" ] || return 0
  notify-send -t 1500 -a speak-selection "$label" 2>/dev/null || true
}
```

The `isError` flag bypasses the `NOTIFICATIONS_ENABLED` gate. Errors
are operationally important and shouldn't be silenced by a dev
toggle — if something breaks, the user always sees it. Error
notifications also use a longer timeout (3 seconds vs 1.5) and the
`critical` urgency level so the future indicator can render them
distinctly from lifecycle events.

Logging stays on its own absolute gate: an error still doesn't write
to disk if `loggingEnabled = false`. If a user wants to investigate
*why* an error fired, they flip `devMode = true` and reproduce.

Initial label vocabulary (extend as features are added):

- `processing-start` — fired from the `--run` child after sanitization
  succeeds and the first chunk is about to be POSTed
- `processing-end` — fired from the `--run` child when the pipeline
  drains naturally on clean EOF
- `cancelled` — fired from the MAIN branch the moment a second
  hotkey press initiates the kill of an in-flight reader. Fires
  immediately on press so a future indicator can flip state without
  waiting for SIGTERM to propagate down the pipeline.
- `synth-error` — fired from the synth loop with `isError = true`
  when a chunk POST fails (non-200 status, curl timeout, daemon
  unreachable). Always shown regardless of `notificationsEnabled`.

Why a single chokepoint with a single string argument: the function
boundary is the place to swap implementations later. To drive a
top-bar indicator, you replace the body to write to a named pipe or
dbus path that the indicator daemon listens on; the call sites
upstream don't change. To send to a different notification daemon,
same story. Keeping the argument as one opaque label string (rather
than separate title/body/icon parameters) means future indicators
can map labels to whatever visual or audio cue they want without
the script needing to know.

`pkgs.libnotify` is added to `runtimeInputs` so `notify-send` is
available. If a future swap drops libnotify, the input goes too —
contained inside the helper, not leaked into `environment.systemPackages`.

## Target Files
- `modules/nixos/scripts/speak-selection.sh` — replace the single
  `curl | aplay` line in the `--run` branch with the chunk-loop
  pipeline; add `sanitize_text` (data-driven over the sanitize-rules
  array), `split_into_chunks`, the two empty-input guards, and the
  `sendNotification` helper. Gate `log()` on `LOGGING_ENABLED`.
  Existing cleanup and PGID logic is unchanged.
- `modules/nixos/tts.nix` — add the user-facing options
  (`devMode`, `loggingEnabled`, `notificationsEnabled`), the new
  internal settings keys, the `sanitizeRules` attrset, a renderer
  that emits the rules as a shell array into `settingsPreamble`, a
  `systemd.user.tmpfiles.rules` block for the log directory and
  age-based cleanup, and `pkgs.libnotify` in `runtimeInputs` of the
  `speakSelection` shell application. Sanitization and chunking are
  still pure shell/sed/awk; the streaming pipeline still uses only
  curl, jq, and alsa-utils.
- **Single PR.** Sanitization, chunking, and streaming ship together
  rather than as a phased rollout — the rules are simple enough that
  the bisect risk is low, and the end-to-end behavior change is what
  the user is actually buying.

## Decisions to Confirm

- **One sentence or 200 chars on a word boundary, whichever is
  shorter:** a fixed cap is easier to reason about than the dynamic
  mean-sentence-length math in earlier drafts and avoids the
  degenerate case where a tiny selection produces a tiny cap that
  splits mid-sentence. Two-hundred characters is short enough that
  even a single oversized chunk synthesizes well under a second on
  warm piper, keeping first-audio latency low.
- **Streaming pipe over file-based queue:** an earlier draft had the
  synth worker write numbered WAVs to a tmpdir while a player worker
  consumed them via inotify. That design assumed parallel synthesis,
  which piper-server doesn't actually offer (single instance,
  serial). Without parallelism, the queue gives nothing and adds a
  lot of state — temp files, end-of-stream flags, cleanup traps on
  three exit paths. The pipe-based version keeps the same
  time-to-first-audio guarantee with roughly a third of the
  complexity.
- **Replacing code fences with the phrase "Code Example":** the
  listener gets an audible marker where the block sat, instead of a
  jarring jump from prose to prose with the code silently missing.
- **URL collapse rule:** keep the hostname, drop the path. Reading
  domains aloud is useful for source attribution; reading paths is
  noise.

## Status
Not implemented. PRD only.
