# Background-Script Status Indicators PRD

## Goal
Long-running helper scripts (TTS today, STT next, more later) should
have a passive visual channel in the top bar so I can glance up and see
what they're doing — without firing notifications. Each helper gets one
small indicator that appears when the script is active, changes
appearance per phase (e.g. listening vs. processing), and disappears
when idle. Hyprland is the priority; GNOME parity is a nice-to-have
later.

## Current State

### Top bar: Waybar
`modules/home-manager/hyprland/bar.nix` defines a single `mainBar`.
`modules-right` currently holds `tray`, `pulseaudio`, `network`,
`battery`, and one existing `custom/power` module. Styling is class
based, e.g. `#battery.warning` and `#battery.critical` carry color
overrides. Waybar is launched by Hyprland's `exec-once`, not the user
systemd service.

### Background scripts that need indicators
- **`speak-selection`** from `modules/nixos/tts.nix`. Two phases I want
  to surface: synthesizing audio against `piper-server`, and playing
  the result through `aplay`.
- **`dictate`** (planned in `11-speech-to-text.md`). Two phases:
  recording from the mic, and posting the WAV to the local Whisper
  daemon for transcription.

### What's not in place
There is no shared notion of "background script state" today, and
neither helper emits anything the bar can read. `libnotify` / `mako`
exist for transient notifications, but those are explicitly the wrong
channel for this — the whole point is a passive indicator that lives in
the bar, not a popup that has to be dismissed.

### GNOME (background, not in scope for v1)
GNOME has its own top bar and the AppIndicator extension is already
enabled in `modules/home-manager/desktop.nix`. No status-indicator
infrastructure exists on the GNOME side either. v1 ships Hyprland-only;
GNOME parity is deferred.

## References

- **Existing custom-module precedent:** `custom/power` in
  `modules/home-manager/hyprland/bar.nix:63-67` is the closest existing
  shape in the repo.
- **Existing class-based color precedent:**
  `modules/home-manager/hyprland/bar.nix:94-95` (battery warning /
  critical).
- **Companion PRDs:** `01-terminal.md` (style reference),
  `11-speech-to-text.md` (one of the helpers this serves).

## Desired Behavior

### From the user's seat
When a background helper is idle, nothing new appears in the bar. The
moment a helper starts working, a small indicator appears in a stable
spot on the right side of the bar. As the helper moves between phases,
the indicator changes color (and tooltip) to reflect the phase. When
the helper finishes, the indicator disappears again. Multiple helpers
can show indicators side by side, each one independent.

### Per-helper indicator behavior
- **TTS** has two visible phases: synthesizing speech, and playing it
  back. These should be visually distinguishable from each other.
- **STT** has two visible phases: listening to the mic (red) and
  transcribing (green).

### Adding a new indicator should be cheap
The whole point of building this once is so the next background helper
I write can opt into the indicator system with a small amount of
config — name, phases, and a color per phase — without touching the
bar config or the styling directly.

## Scope

- **In scope (v1):** Hyprland / Waybar. Indicators for TTS and STT.
  A clear, documented way to add a new indicator for a future helper.
- **Out of scope (v1), nice-to-have later:** GNOME top-bar parity.
  Whatever shape v1 takes, the per-helper state should be exposed in a
  way that does not lock out a future GNOME implementation.

## Decisions to Confirm

- **Visual encoding per phase.** Single colored dot vs. per-phase
  glyphs (e.g. microphone, speaker, gear). Dots scale calmly to many
  helpers; glyphs read as more semantic but get visually noisy fast.
  Leaning dots; not committed.
- **TTS color palette.** I originally said "blue" for both decoding
  and reading aloud, which collapses two distinct phases into one
  signal. Need to pick two cool-family colors that are distinguishable
  at a glance, or accept that the two TTS phases look the same.
- **STT color palette.** Red while listening, green while processing.
  Confirmed in conversation, captured here.
- **Position in the bar.** Where in `modules-right` the indicators
  live, and whether their order is stable across helpers.
- **Click behavior.** Whether clicking an indicator does anything
  (e.g. clicking the TTS dot during playback could stop playback,
  reusing the existing press-toggle script). Open question.

## Target Files
The right place for the indicator config and the helper-side state
emission isn't fully decided yet — see Developer Notes. As a starting
guess: a new file under `modules/home-manager/hyprland/`, small edits
to the existing helper scripts under `modules/nixos/scripts/`, and a
one-line enable in `home/hugo/default.nix`. Treat this list as a
sketch, not a contract.

## Developer Notes (exploratory, not commitments)

These are ideas worth investigating once implementation starts. None
of them are verified against the actual Waybar / Hyprland / NixOS
behavior on this machine, and any of them may turn out to be wrong or
to have a better alternative.

- **Possible mechanism: Waybar custom modules.** Waybar's `custom/<name>`
  modules can run a shell script and expect either plain text or JSON on
  stdout. They support polling on an interval and (allegedly) push
  updates via a real-time signal. The `custom/power` module already in
  this repo is the closest precedent to copy from.

- **Possible state contract: per-helper state file.** Each helper
  writes a single short word (e.g. `listening`, `processing`) to a file
  under `$XDG_RUNTIME_DIR`, and the bar reads it. Atomic writes via
  write-then-rename would avoid tearing. This would also be the seam
  that lets a future GNOME implementation read the same state without
  changing the helpers.

- **Possible push-update mechanism.** Waybar reportedly accepts
  `SIGRTMIN+N` to refresh a specific custom module on demand. If that
  works, helpers could nudge the bar instantly via `pkill -RTMIN+N
  waybar` instead of polling. Needs verification on this Waybar build.

- **Possible Nix shape.** A new home-manager module that exposes an
  attrset of indicator definitions (name, phases, colors) and generates
  the corresponding Waybar custom-module entries and CSS rules. This is
  the part most likely to change once the real Waybar API is in front
  of us — could just as easily live as a hand-rolled extension to
  `bar.nix`.

- **Helper-script edits.** Each helper would need a small `set_state`
  function called at phase boundaries, plus a clear-on-exit trap so a
  killed script doesn't leave a stale indicator. The TTS script already
  has lock-file plumbing under `$XDG_RUNTIME_DIR` to crib from.

- **Cross-DE alternative considered.** A StatusNotifierItem (SNI)
  publishing daemon would be consumed by both Waybar's `tray` module
  and GNOME's AppIndicator extension. This is the canonical
  cross-desktop approach. Rejected for v1 because it adds a persistent
  D-Bus process and a library dependency for what is currently two
  dots in a bar; revisit if GNOME parity becomes real.

## Status
Not implemented. State contract not yet defined; helper scripts do not
emit state; no indicator infrastructure exists in the bar.
