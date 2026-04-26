# Custom Touch Keyboard PRD

## Goal
A small one-handed on-screen keyboard for Hyprland, pinned to a corner of the screen, with a row of macro buttons for complex keybindings. Used when the full-width OSK from the touchscreen support PRD is too intrusive — typing in a chat or terminal while still needing to see the app.

Not a replacement for the full-width OSK. The full-width OSK handles the keystone "any input becomes typeable" case. This handles the long-form typing case where the keyboard needs to share screen space with the app.

## Workflow
- One-handed layout: thumb-reachable, pinned to the bottom-left or bottom-right corner.
- Macro row above the keys: icon buttons for complex Hyprland keybindings the user would otherwise need a physical keyboard chord for (close window, switch workspace, app switcher, etc.). The macro row is the reason to build this rather than ship a stock OSK at half size.
- Toggleable from the same Waybar tablet-mode button group that toggles the full-width OSK, or from a dedicated button.
- Hand-switchable: a single tap to flip between bottom-left and bottom-right anchor.

## Out of Scope
- Full keyboard parity with the physical keyboard. This is a typing aid, not a replacement.
- Predictive text or swipe input. Tap-only is fine for v1.

## Open Questions
- Build from scratch in EWW, or patch/wrap an existing OSK (wvkbd, maliit) so it renders inside a constrained EWW window?
- Which macros earn a button. Initial guesses: close active window, app switcher, workspace next/prev, show full-width OSK, dismiss keyboard.
- How macros that need a real keypress (e.g. Super+Q) get sent to the focused window — `hyprctl dispatch sendshortcut` vs `wtype` vs `ydotool`.

## Current State
_Not started. Touchscreen support PRD (17) ships the full-width OSK first; this PRD picks up once that is in daily use and the full-width form factor is felt as a limitation._

## References
_GitHub URLs and the specific parts we want from each. To be filled in._

- URL:
  - What to take:

## Proposed Changes
_Concrete edits, scoped to files below. To be filled in._

## Target Files
_Which modules in this repo get touched. To be filled in._
