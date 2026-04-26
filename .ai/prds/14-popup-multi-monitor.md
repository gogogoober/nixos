# Quick-Popup Multi-Monitor Support PRD

## Goal
Make the quick-popup host (music, volume, wifi, bluetooth, and any
future popup) behave correctly when more than one monitor is
connected. Today the launcher and click handler infer "which special
workspace is currently shown" by looking at the first monitor only.
On a multi-monitor setup that breaks: a persistent popup shown on
monitor B is invisible to logic running against monitor A, so toggling
misfires and the dismiss-on-outside-click does the wrong thing.

## Current State

### Single-monitor today
The user runs a single laptop screen. The bug exists in the code but
has never bitten because there is only one monitor to read.

### Where the assumption lives
Two scripts each pick a single active special workspace by piping
`hyprctl monitors -j` through `jq` and `head -1`:
- `modules/home-manager/hyprland/quick-popups/scripts/launcher.sh`
  reads `active_special` once at the top of the dismiss loop.
- `modules/home-manager/hyprland/quick-popups/scripts/click-handler.sh`
  reads `active_special` the same way to decide whether to dismiss
  a persistent popup.

Both then test `case "$active_special" in *"$c_workspace") ...`
against that single value, so a persistent popup whose workspace is
the active overlay on a non-first monitor is treated as hidden.

### What works correctly already
Geometry and per-popup window classes are not affected. Each popup
class is unique and the windowrules are global. Ephemeral popups are
also unaffected because their visibility check does not depend on
which monitor's special workspace is active — they are visible
whenever their client exists.

## References
- `modules/home-manager/hyprland/quick-popups/host.nix` — host module
  that generates the scripts.
- `modules/home-manager/hyprland/quick-popups/scripts/launcher.sh:38`
  — first `head -1` site.
- `modules/home-manager/hyprland/quick-popups/scripts/click-handler.sh:30`
  — second `head -1` site.
- `05-quick-settings-v2.md` — the original popup host design.

## Proposed Changes

### Resolve the popup's monitor before checking visibility
Each persistent popup is assigned to a single special workspace by
windowrule. The launcher and click handler should look up which
monitor currently owns that popup's client, then read that
monitor's active special workspace — not the first one found.
Sketch:

```sh
client=$(printf '%s' "$clients_json" | jq --arg c "$target_class" \
  '[.[] | select(.class == $c)] | first')
mon_id=$(printf '%s' "$client" | jq -r '.monitor')
active_special=$(hyprctl monitors -j \
  | jq -r --argjson m "$mon_id" '.[] | select(.id == $m) | .specialWorkspace.name')
```

This makes visibility a question per popup, not per session.

### Decide cursor-monitor for the click handler
The click handler iterates every visible popup. For each persistent
candidate, it should read that popup's current monitor (as above) to
test visibility. The "cursor inside popup" check already uses
absolute coordinates and Hyprland reports per-popup `at` and `size`
in absolute monitor space, so the inside test does not need to
change.

### Confirm geometry under multi-monitor
The `move (monitor_w-window_w-X) Y` rule is monitor-relative in
Hyprland: a popup that opens on monitor B anchors to monitor B's
top-right. Verify that holds for both ephemerals (which pick the
focused monitor) and persistents (which open via toggling their
special workspace onto whichever monitor is active). Document any
quirks discovered.

## Open Questions

🟡 What is the right policy when a persistent popup's special
workspace is "everywhere" (Hyprland can pin special workspaces per
monitor or share them)? Pick the focused monitor at click time, or
the monitor where the popup last lived?

⚪ Do we need a smoke test that exercises the multi-monitor path
without actually requiring two screens? `hyprctl` has no headless
mode, so this might just be "manual verification when the second
monitor is plugged in."

## Out of Scope
- Per-monitor distinct popup geometry (different size on a 4K
  external vs. the laptop panel). Tracked here as a follow-on if it
  becomes painful, not part of v1 multi-monitor support.
- Mirroring a popup across monitors. The intent stays: one popup
  visible at a time, on one monitor at a time.
