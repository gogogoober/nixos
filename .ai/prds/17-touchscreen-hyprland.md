# Touchscreen Support (Hyprland) PRD

## Goal
Make the Hyprland desktop fully usable on a Surface tablet without a keyboard attached: text input, app launching, and core controls all reachable by touch alone.

## Requirements
- **On-screen keyboard:** auto-show an OSK (squeekboard, wvkbd, or similar) whenever the user focuses an editable input, auto-hide when focus leaves. Needs to work across GTK, Qt, Electron, and terminal apps.
- **Keyboard-detached detection:** detect when the Surface Type Cover is disconnected or folded back so the system can switch into a touch-first mode (OSK behavior, scaled UI, gesture set). Likely a udev rule plus a small daemon that writes a state file other components read.
- **Large-target app launcher:** Walker (or a separate touch-mode launcher) configured with big icons and tap-to-launch, usable without typing to filter. Reachable by an edge gesture or on-screen button, not only by keybind.
- **Other essentials for a Surface tablet:**
  - Auto-rotation driven by the accelerometer (portrait/landscape), wired into Hyprland's monitor transform.
  - Pen/stylus input with palm rejection.
  - Touch gestures for workspace switch, overview, and back (hyprgrass or built-in gestures).
  - Touch-reachable brightness and volume controls in Waybar or as edge popups.
  - On-screen way to lock, reboot, and shut down without a keyboard.

## Current State
_To be filled in once we audit the Hyprland modules, surface-go-3 host config, and existing input/gesture setup._

## References
_GitHub URLs and the specific parts we want from each._

- URL:
  - What to take:

## Proposed Changes
_Concrete edits, scoped to files below. To be filled in._

## Target Files
_Which modules in this repo get touched. To be filled in._
