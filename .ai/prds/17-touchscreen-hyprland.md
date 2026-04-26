# Touchscreen Support (Hyprland) PRD

## Goal
Physical-keyboard-first experience, with a small set of essential tasks reachable by touch alone when the Type Cover is detached. Not full touch parity — just enough that the airplane scenario works (connect to WiFi, change volume, switch apps, type into a field, close a window, lock the screen).

## Essential Touch-Only Tasks
The minimum set the system must support without a keyboard:
- Type into a focused input.
- Connect to a WiFi network.
- Connect to a Bluetooth device (e.g. headphones).
- Adjust volume and brightness.
- Switch between open apps.
- Close the active window.
- Open a launcher and start a new app.
- Lock, reboot, or shut down.
- Detect when the Type Cover is detached and surface a tablet-mode UI for the items above.
- Scale the top nav (Waybar) up when in tablet mode so buttons are large enough to tap reliably. Driven off the same tablet-mode flag.

Out of scope: full window management by touch, workspace gymnastics, complex window rules, anything that's faster on the keyboard.

## Research

### Solved with existing tools
- **WiFi:** `iwgtk` for iwd, or a Waybar dropdown for NetworkManager. Touch-friendly GTK frontend.
- **Bluetooth:** `overskride`, GTK4, built for touch, in nixpkgs.
- **Volume + brightness:** `swayosd` daemon bound to XF86 keys, plus optional Waybar slider modules.
- **Power menu:** `wlogout` with `--buttons-per-row 3` for big touch targets.
- **Auto-rotation:** `iio-hyprland` (nixpkgs module) handles screen + touch transforms together via `iio-sensor-proxy`. Don't pin per-device input transforms in Hyprland config or it blocks rotation.
- **Touch gestures (optional):** `hyprgrass` plugin, alpha — author warns it can wedge touch input. Defer until phase 2.
- **App launcher:** Walker or fuzzel scale icons via config; good enough as a fallback grid. A custom EWW grid is the next step up if needed.

### DIY territory
- **OSK auto-show on input focus:** Hyprland's input-method/text-input integration is incomplete, so no off-the-shelf OSK auto-shows reliably. `wvkbd` is the dominant pick, controlled by signals (`SIGUSR1` hide, `SIGUSR2` show, `SIGRTMIN` toggle). Implies a manual toggle button (Waybar / EWW) or a tablet-mode trigger.
- **Type Cover detach detection:** `SW_TABLET_MODE` is unreliable on linux-surface, especially for the Surface Go 3. Need a udev rule watching the Type Cover input device add/remove and writing a state file (e.g. `/run/user/$UID/tablet-mode`) other components read.
- **Bottom-left one-handed OSK + EWW hotkey row above it:** unbuilt anywhere public. `wvkbd` always spans the output width via wlr-layer-shell, so getting a small bottom-left keyboard means either patching wvkbd's anchor/exclusive-zone code or wrapping it inside a constrained EWW window. Hotkey row itself is straightforward EWW (layer-shell window, fixed height, buttons calling `hyprctl dispatch killactive`, etc.). Treat as phase 2.

### Recommended phasing
**Phase 1 — get the airplane scenario working:**
1. udev rule for Type Cover detach → state file.
2. Waybar tablet-mode button group that appears when state is on: OSK toggle, WiFi (iwgtk), Bluetooth (overskride), power (wlogout).
3. `wvkbd` full-width, manually toggled.
4. `swayosd` for volume + brightness (already useful even with keyboard).
5. `iio-hyprland` for rotation.

**Phase 2 — only if phase 1 annoys daily use:**
- Custom one-handed OSK + EWW hotkey row.
- `hyprgrass` for edge gestures.
- Touch-grid EWW launcher.

### Surface Go 3 prior art
Thin. `nixos-hardware` ships a `microsoft-surface-go` module. Surface Go 2 NixOS wiki page is the closest reference. No public Surface Go 3 + Hyprland dotfile repo found.

### Sources
- wvkbd: https://github.com/jjsullivan5196/wvkbd
- hyprkbd (early Hyprland fork): https://github.com/JeanSchoeller/hyprkbd
- Hyprland OSK auto-show issue: https://github.com/hyprwm/Hyprland/issues/6195
- Hyprland utilities wiki (iwgtk, overskride, wlogout, nm-applet): https://wiki.hypr.land/Useful-Utilities/Other/
- swayosd: https://github.com/ErikReider/SwayOSD
- iio-hyprland: https://github.com/JeanSchoeller/iio-hyprland
- iio-hyprland nixpkgs module: https://github.com/NixOS/nixpkgs/blob/release-25.11/nixos/modules/programs/iio-hyprland.nix
- hyprgrass: https://github.com/horriblename/hyprgrass
- linux-surface SW_TABLET_MODE issue: https://github.com/linux-surface/linux-surface/issues/735
- nixos-hardware Surface modules: https://github.com/NixOS/nixos-hardware/blob/master/microsoft/surface/README.md
- Surface Go 2 NixOS wiki: https://wiki.nixos.org/wiki/Hardware/Microsoft/Surface_Go_2
- wlr-layer-shell protocol (for any wvkbd anchor patching): https://dev.tarina.org/p/wvkbd/file/proto/wlr-layer-shell-unstable-v1.xml.html
- awesome-hyprland: https://github.com/hyprland-community/awesome-hyprland

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
