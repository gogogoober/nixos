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

## Architecture

**Principle: open for extension, closed for modification.** All touchscreen logic lives in a single Hyprland sub-module (`modules/home-manager/hyprland/touchscreen.nix`). Other Hyprland modules (bar, windows, keybinds, etc.) stay touch-unaware. Instead of growing `if touchscreen` branches across the codebase, each affected base module exposes a small set of extension hooks (option paths that take lists, attrsets, or strings) and the touchscreen module fills them in via `mkIf cfg.enable`.

This keeps the cost of a future "remove touchscreen" or "swap implementation" change local: delete one file, no grep across the system.

### The touchscreen module owns
- The tablet-mode flag service (libinput watcher → state file).
- The wvkbd user service and toggle script.
- All tablet-mode CSS (delivered through `bar`'s extension hook, not embedded in `bar.nix`).
- The Waybar tablet-mode button group definitions (delivered through `bar`'s extension hook).
- Touchscreen-specific window rules (delivered through `windows`'s extension hook).
- Touchscreen-specific keybinds (delivered through `keybinds`'s extension hook).
- The iio-hyprland enable + any pen/palm config.

### Extension hooks each base module exposes
- **bar.nix** — `extraModules` (list of module names appended to the right modules group), `extraModuleDefinitions` (attrset merged into Waybar's `custom/...` definitions), `extraStyles` (CSS string concatenated after the base stylesheet), `extraClasses` (list of class names the bar may wear at runtime — explicit contract surface for state-driven styling).
- **windows.nix** — `extraWindowRules` (list of `windowrulev2 = ...` strings appended to the base set).
- **keybinds.nix** — `extraBinds` (list of bind strings, including `bind`, `bindl`, `bindle` flavors, appended to the base set).
- **default.nix** — composition only. No extension hook needed; the touchscreen module imports itself.

`extraClasses` is the registration surface for global state styling. Touch is the first consumer (registers `tablet`); a future kiosk or presenter mode would register its own class. The mechanism: a consumer adds a polling custom module via `extraModuleDefinitions` whose JSON `class` field tracks a state file, then ships CSS via `extraStyles` using `:has()` selectors keyed on that class. The `extraClasses` list is what makes the contract explicit so consumers don't silently collide on a name.

The hooks have empty defaults so the system behaves identically to today on any laptop or desktop with no touchscreen module enabled. The hooks are the extension surface; the defaults are the closed-for-modification base.

### What this rules out
- No `mkIf config.modules.touchscreen.enable` inside `bar.nix`, `windows.nix`, etc. The base modules don't reference touchscreen options.
- No CSS file shared between `bar.nix` and `touchscreen.nix`. Touchscreen-related CSS is constructed inside the touchscreen module and handed to the bar through `extraStyles`.
- No "touchscreen-aware" branch in the Walker config. If touch needs a different launcher, ship it as a separate launcher invoked from a tablet-mode button, not by mutating Walker.

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
- **Type Cover detach detection:** the linux-surface typecover patch makes the cover emit `SW_TABLET_MODE` via a virtual input device named "Surface Type Cover Tablet Mode Switch". A small user-level service watching that switch with `libinput debug-events` is cleaner than udev (udev runs as root with no DBus / XDG_RUNTIME_DIR). Service writes the flag to a state file (e.g. `$XDG_RUNTIME_DIR/tablet-mode`).
- **Bottom-left one-handed OSK + EWW hotkey row above it:** unbuilt anywhere public. `wvkbd` always spans the output width via wlr-layer-shell, so getting a small bottom-left keyboard means either patching wvkbd's anchor/exclusive-zone code or wrapping it inside a constrained EWW window. Hotkey row itself is straightforward EWW (layer-shell window, fixed height, buttons calling `hyprctl dispatch killactive`, etc.). Treat as phase 2.

### Recommended phasing

**Phase 0 — add extension hooks to base modules (prerequisite, no consumer yet):**
1. `bar.nix` exposes `extraModules`, `extraModuleDefinitions`, `extraStyles`, `extraClasses`. Existing config still renders identically when all four are empty.
2. `windows.nix` exposes `extraWindowRules`. Same: empty default → no behavior change.
3. `keybinds.nix` exposes `extraBinds`. Same.
4. Land these in their own commit so the diff to the base modules is reviewable on its own, before any touchscreen code consumes them.

**Phase 1 — get the airplane scenario working:**
1. User-level service watching `SW_TABLET_MODE` via libinput → writes state file.
2. Waybar tablet-mode button group that appears when state is on: OSK toggle, WiFi (iwgtk), Bluetooth (overskride), power (wlogout).
3. `wvkbd` full-width, started hidden, toggled with `pkill -RTMIN+8 wvkbd-mobintl`.
4. `swayosd` for volume + brightness (already useful even with keyboard).
5. `iio-hyprland` for rotation.
6. `nixos-hardware` Surface Go module + linux-surface kernel.

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
- linux-surface typecover patch (the patch that emits the tablet-mode switch event): https://github.com/linux-surface/linux-surface/tree/master/patches
- wlogout layer-shell click hang: https://github.com/hyprwm/Hyprland/issues/4599
- nixos-hardware Surface modules: https://github.com/NixOS/nixos-hardware/blob/master/microsoft/surface/README.md
- Surface Go 2 NixOS wiki: https://wiki.nixos.org/wiki/Hardware/Microsoft/Surface_Go_2
- wlr-layer-shell protocol (for any wvkbd anchor patching): https://dev.tarina.org/p/wvkbd/file/proto/wlr-layer-shell-unstable-v1.xml.html
- awesome-hyprland: https://github.com/hyprland-community/awesome-hyprland

## Implementation Plan

Concrete wiring for each piece. Snippets are sketches, not final code. Per the Architecture section, all owned logic lives in `modules/home-manager/hyprland/touchscreen.nix`; "Hooks used" lists which extension points it consumes on base modules.

### Phase 0: hook surface on base modules

The hooks are added with empty defaults. No touchscreen consumer in this phase. Goal: the diff to base modules ships and reviews cleanly on its own, and the system behaves identically.

**`bar.nix`** — add an options block:
```nix
options.modules.hyprland.bar = {
  extraModules = mkOption {
    type = types.listOf types.str;
    default = [];
    description = "Waybar module names appended to the right modules group.";
  };
  extraModuleDefinitions = mkOption {
    type = types.attrsOf types.attrs;
    default = {};
    description = "custom/<name> Waybar module definitions merged into the bar config.";
  };
  extraStyles = mkOption {
    type = types.lines;
    default = "";
    description = "CSS appended after the base stylesheet.";
  };
  extraClasses = mkOption {
    type = types.listOf types.str;
    default = [];
    description = ''
      Class names the bar may wear at runtime, registered as the contract for state-driven styling.
      Consumers drive the class with a polling custom module added via extraModuleDefinitions and
      ship matching CSS through extraStyles (typically using :has() selectors). The list is the
      explicit registry so multiple consumers don't collide on the same name.
    '';
  };
};
```
Then in the `config` block: append `cfg.bar.extraModules` to the `modules-right` list, merge `cfg.bar.extraModuleDefinitions` into the Waybar settings, concatenate `cfg.bar.extraStyles` after the base stylesheet string. `extraClasses` is consumed for documentation today; if the bar later grows a content wrapper that auto-applies registered classes, the consumers don't need to change.

**`windows.nix`** — add an options block:
```nix
options.modules.hyprland.windows = {
  extraWindowRules = mkOption {
    type = types.listOf types.str;
    default = [];
    description = "Hyprland windowrulev2 strings appended to the base rules.";
  };
};
```
Then concatenate `cfg.windows.extraWindowRules` into the `windowrulev2` list in the Hyprland settings.

**`keybinds.nix`** — add an options block:
```nix
options.modules.hyprland.keybinds = {
  extraBinds = mkOption {
    type = types.attrsOf (types.listOf types.str);
    default = {};
    description = "Extra Hyprland binds, keyed by bind flavor (bind, bindl, bindle, ...). Each list is appended to the base for that flavor.";
  };
};
```
Then for each flavor (`bind`, `bindl`, `bindle`, etc.) append `cfg.keybinds.extraBinds.<flavor> or []` to the base list.

Phase 0 is done when:
- All three modules expose their hooks with empty defaults.
- `nixos-rebuild switch` produces a no-op diff vs. the previous generation.
- A trivial test consumer (e.g. a one-line `extraBinds.bind = [ "$mod, F1, exec, notify-send hello" ];` in a separate file) actually applies, proving the wiring works.

### 1. Tablet-mode flag (Type Cover detach)
- Mechanism: user-level systemd service runs `libinput debug-events --device /dev/input/by-id/...-tablet-mode-switch`, parses `SW_TABLET_MODE 1/0`, writes `0` or `1` to `$XDG_RUNTIME_DIR/tablet-mode`.
- Why user service, not udev: udev runs as root without DBus or `XDG_RUNTIME_DIR`. A user service has the right env and can run a one-line shell loop.
- Surface Go 3 specifics: linux-surface typecover patch creates the "Surface Type Cover Tablet Mode Switch" virtual device. Confirm device name with `libinput list-devices` once the host boots.
- Owned by: `touchscreen.nix` (defines `systemd.user.services.tablet-mode`).
- Hooks used: none — internal to the touchscreen module.

### 2. wvkbd toggle
- Package: `pkgs.wvkbd`, binary `wvkbd-mobintl`.
- Run as a user service started with `--hidden`. Toggle with `pkill -RTMIN+8 wvkbd-mobintl` (per upstream README convention).
- Bind the toggle from a Waybar custom module **and** a Hyprland keybind, so both touch and keyboard reach it.
- Owned by: `touchscreen.nix`.
- Hooks used: `bar.extraModules` + `bar.extraModuleDefinitions` (the OSK toggle button), `keybinds.extraBinds` (the keyboard shortcut for the toggle).

### 3. Waybar tablet-mode button group + scaled top nav
- Pattern: one Waybar config, one custom module whose `exec` shells out to `cat "$XDG_RUNTIME_DIR/tablet-mode"` every 1s and emits JSON with `class: "tablet"` when active. CSS rules use `:has()` selectors to scale and reveal children when that class is present.
- Path expansion gotcha: Waybar config strings are not shell-expanded, so `$XDG_RUNTIME_DIR` only works inside an `exec` field that runs through a shell. Don't put the env-var path in fields like `path` or `format`.
- Why one config, not two: switching between two configs requires kill+restart, which flickers and drops tooltips. CSS class swap is live.
- Buttons in the group (visible only when `.tablet` is set):
  - **OSK toggle** → `pkill -RTMIN+8 wvkbd-mobintl`
  - **WiFi** → launches `iwgtk`
  - **Bluetooth** → launches `overskride`
  - **Power** → launches `wlogout --protocol xdg-shell`
- Top nav scale-up: same `.tablet` class scales `padding`, `font-size`, and icon size in the stylesheet.
- Owned by: `touchscreen.nix` (button definitions, polling module, CSS).
- Hooks used: `bar.extraClasses = [ "tablet" ]` (registers the class), `bar.extraModuleDefinitions` (the polling module + button definitions), `bar.extraModules` (the button list appended to modules-right), `bar.extraStyles` (the scaling CSS using `:has(.tablet)` selectors). `bar.nix` itself never references touchscreen.

### 4. swayosd
- Home-manager option: `services.swayosd.enable = true` (set inside `touchscreen.nix`).
- Hyprland keybinds (XF86 keys) — use `bindle` (locked + repeat) for sliders, `bindl` (locked) for mute toggle:
  ```
  bindle = , XF86AudioRaiseVolume, exec, swayosd-client --output-volume raise
  bindle = , XF86AudioLowerVolume, exec, swayosd-client --output-volume lower
  bindl  = , XF86AudioMute,        exec, swayosd-client --output-volume mute-toggle
  bindle = , XF86MonBrightnessUp,   exec, swayosd-client --brightness raise
  bindle = , XF86MonBrightnessDown, exec, swayosd-client --brightness lower
  ```
- Owned by: `touchscreen.nix`.
- Hooks used: `keybinds.extraBinds` for the XF86 lines.

### 5. wlogout
- Home-manager option: `programs.wlogout.enable = true` (set inside `touchscreen.nix`). `layout` and `style` defined inline.
- Layout: 3 buttons per row, large icon labels (lock, suspend, reboot, shutdown, logout).
- Workaround for layer-shell click hang: launch with `--protocol xdg-shell` (loses background transparency, accept it).
- Owned by: `touchscreen.nix`.
- Hooks used: none — wlogout is launched from a Waybar button registered through `bar.extraModuleDefinitions` (already counted in #3).

### 6. iio-hyprland (auto-rotation)
- NixOS option: `programs.iio-hyprland.enable = true` (the module also enables the package and `hardware.sensor.iio.enable`).
- Gotcha: any explicit `device:<touchscreen>:transform` block in Hyprland config blocks rotation. Remove static touch device transforms before enabling.
- Static landscape `monitor` line is fine — iio-hyprland updates it via `hyprctl` at runtime.
- Owned by: `modules/nixos/touchscreen.nix` (system-level enable). `modules/home-manager/hyprland/touchscreen.nix` only checks the option is on for the host.
- Hooks used: none on Hyprland sub-modules — interacts with monitor transforms via runtime hyprctl, not the config.

### 7. linux-surface kernel + Surface Go 3 hardware
- Import `nixos-hardware` Surface Go path (deprecated to import the surface default directly — use the per-model subdirectory).
- Settings:
  - `hardware.microsoft-surface.kernelVersion = "longterm"`
  - `hardware.microsoft-surface.surface-control.enable = true`
- Surface Go 3 does **not** use IPTS, so do **not** enable `services.iptsd`.
- Owned by: `hosts/surface-go-3/default.nix` (the import) + `modules/nixos/touchscreen.nix` (the surface options, gated on `cfg.enable`).
- Hooks used: none.

### 8. iwgtk + overskride window rules
- Both packaged as `pkgs.iwgtk` and `pkgs.overskride`.
- Launch from Waybar `on-click` running the binary directly (Waybar inherits the Hyprland env).
- Hyprland windowrules to float and size them touch-friendly (~600×800, centered):
  ```
  windowrulev2 = float,        class:^(iwgtk)$
  windowrulev2 = size 600 800, class:^(iwgtk)$
  windowrulev2 = center,       class:^(iwgtk)$
  ```
  Same shape for `overskride`.
- Owned by: `touchscreen.nix`.
- Hooks used: `windows.extraWindowRules` for the float/size/center rules.

### 9. Pen + palm rejection (deferred)
- Needs the actual pen device name from `hyprctl devices` on a running Hyprland session, so this can't fully land until after first Hyprland boot on the Go 3.
- Hyprland has no first-class palm rejection knob — relies on the kernel driver's reporting.
- Phase 2 task once Hyprland is running on the Go 3.
- First-boot capture procedure (run once after Hyprland comes up on the Go 3):
  1. `hyprctl devices > /tmp/devices.txt` — dumps every input device with its name.
  2. Identify the pen, the touchscreen, and the Type Cover tablet-mode switch by name.
  3. Add per-device `input` blocks to `touchscreen.nix` keyed on those names.
  4. Re-run libinput watcher service with the captured switch device path.

### Phase 1 done when
On the Surface Go 3 with Hyprland running:
- Folding the Type Cover back flips `$XDG_RUNTIME_DIR/tablet-mode` from `0` to `1` within ~1s.
- When the flag is `1`, the Waybar tablet button group appears and the bar elements are visibly larger.
- Tapping the OSK button shows wvkbd; tapping again hides it.
- Tapping the WiFi button opens a touch-sized iwgtk window, scanning for networks.
- Tapping the Bluetooth button opens overskride.
- Tapping the power button opens wlogout with three large buttons per row.
- XF86 volume and brightness keys produce a visible swayosd indicator.
- Rotating the device produces a corresponding screen + touch input rotation within ~1s.
- Reattaching the Type Cover flips the flag back to `0`, hides the tablet button group, and restores the normal bar size.

### Hooks summary
- `bar.extraModules` — list of module names appended to the right modules group.
- `bar.extraModuleDefinitions` — attrset of `custom/<name>` definitions merged into Waybar settings.
- `bar.extraStyles` — CSS string concatenated after the base stylesheet.
- `bar.extraClasses` — list of class names the bar may wear at runtime; consumers drive these from polling modules + extraStyles.
- `windows.extraWindowRules` — list of `windowrulev2` strings appended to base rules.
- `keybinds.extraBinds` — attrset keyed by bind flavor (`bind`, `bindl`, `bindle`, ...), each value a list of bind strings appended to that flavor's base list.

### Module gating
The Hyprland-side touchscreen module is gated on **both** flags being true:
```nix
config = mkIf (config.modules.touchscreen.enable && config.modules.hyprland.enable) {
  ...
};
```
- `modules.touchscreen.enable` (system-level, already exists in `modules/nixos/touchscreen.nix`) signals "this host has touch hardware."
- `modules.hyprland.enable` signals "this host runs Hyprland."
- Both true → wire the Hyprland touch UI. Either false → no-op.
- This avoids introducing a new option specific to Hyprland touch; we reuse the existing system-level flag.

### Decisions
- **Hyprland is the default.** Surface Go 3 host config will flip to `gnome.enable = false; hyprland.enable = true;` as part of Phase 1 ramp-up. GNOME is not retained as a fallback session.
- **Tablet-mode flag is a state file**, not a systemd target. Simpler for the Waybar polling pattern, no consumers today need target-style activation. Revisit if a non-Waybar consumer needs it.

## Current State
- `modules/nixos/touchscreen.nix` exists as a stub: enables `hardware.sensor.iio` and `libwacom` udev only. No userspace wiring.
- `hosts/surface-go-3/default.nix` sets `modules.touchscreen.enable = true`, `gnome.enable = true`, `hyprland.enable = false`. Switch to Hyprland is planned, not done.
- `hosts/surface-go-3/hardware.nix` is a placeholder stub (will not boot as-is).
- No Hyprland-side touchscreen modules (no OSK, tablet-mode flag, rotation, OSD, power menu).

## References
_GitHub URLs and the specific parts we want from each._

- URL:
  - What to take:

## Proposed Changes
_Concrete edits, scoped to files below. To be filled in._

## Target Files
_Which modules in this repo get touched. To be filled in._
