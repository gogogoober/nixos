# Touchscreen Support (GNOME) PRD

## Goal
Make the GNOME desktop fully usable on a Surface tablet without a keyboard attached: text input, app launching, and core controls all reachable by touch alone.

## Requirements
- **On-screen keyboard:** auto-show GNOME's OSK whenever the user focuses an editable input, auto-hide when focus leaves.
- **Keyboard-detached detection:** detect when the Surface Type Cover is disconnected or folded back so the system can switch into a touch-first mode (OSK behavior, scaled UI, gesture set).
- **Large-target app launcher:** an app picker with big icons and tap-to-launch, usable without typing to filter. Activities overview's icon grid is the likely fit, but it should be reachable by an edge gesture or hardware button, not just the Super key.
- **Other essentials for a Surface tablet:**
  - Auto-rotation driven by the accelerometer (portrait/landscape).
  - Pen/stylus input with palm rejection.
  - Touch gestures for workspace switch, overview, and back.
  - Touch-reachable brightness and volume controls.
  - On-screen way to lock, reboot, and shut down without a keyboard.

## Current State
_To be filled in once we audit GNOME settings, gsettings keys, and any tablet-mode helpers already in the repo._

## References
_GitHub URLs and the specific parts we want from each._

- URL:
  - What to take:

## Proposed Changes
_Concrete edits, scoped to files below. To be filled in._

## Target Files
_Which modules in this repo get touched. To be filled in._
