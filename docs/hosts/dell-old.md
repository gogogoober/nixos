# dell-old

Older Dell laptop. Hyprland, and the host where the custom desktop stack is
actually built.

## Goal

**The Hyprland development host.** The bar, the wofi quick settings, the
floating quick-popups, and the design system are all built and iterated here,
then only the pieces that make sense follow to other hosts. It has a fan and a
bigger screen, so it absorbs long rebuilds and experiments that the Surface
should not be asked to run.

Secondary: keep a six-year-old battery honest, see PRD 15.

## What is turned on

From `hosts/dell-old/default.nix`:

- `hyprland` on, `gnome` off — the inverse of the Surface
- `touchscreen` off
- `tts.devMode = true`, so speech logging and lifecycle notifications are on
  here and nowhere else
- `developer`, `gaming`, `stt`, `desktop`, `common`

Host-local extras:

- `hardware.firmware = [ pkgs.linux-firmware ]`
- `services.fprintd.enable = false`
- Left alt and left control swapped, for macOS muscle memory, in both the X
  keymap and keyd

## Battery

Different problem from the Surface, and the one PRD 15 is about. The gas gauge
has stopped re-learning: `BAT0` reports a design capacity of 4474 mAh against a
current full of 2796 mAh, roughly 62 percent, while the cycle counter still
reads zero on a cell manufactured 2020-03-15.

Unlike the Surface, this machine **does** expose
`charge_control_start_threshold` and `charge_control_end_threshold`, currently
50 and 90. Nothing in this repo writes them, so they are coming from BIOS or a
kernel module default and are invisible to a rebuild. PRD 15 proposes putting
them under `services.tlp` declaratively, plus a one-time recalibration cycle.

Not implemented yet, and the open questions in that PRD are still open.

## Open work

- `modules.intelPowerLimit` is not wired here yet. The module is host-agnostic
  across Intel and this machine is Intel too, so it works unchanged and only the
  watt values differ. Do not copy the Surface numbers: that host is fanless and
  thermally bound, while this one has a fan and is bound by a six-year-old cell.
  Start by reading `/sys/class/powercap/intel-rapl:0/constraint_*_power_limit_uw`
  against `constraint_0_max_power_uw` to see how far above its rating the
  firmware runs it, which is how the Surface finding started.
- PRD 15, declarative charge thresholds plus calibration.
- PRD 14, multi-monitor behaviour for the quick-popups.
- PRD 20, replacing the `fsel` launcher with wofi, which would also drop a
  flake input.

## Caveat

This file is written from the config and the PRDs, not from the running
machine. Anything here about live hardware state is second-hand; verify on the
box before acting on it.

## References

- **Host switchboard:** `hosts/dell-old/default.nix`
- **Hyprland home config:** `modules/home-manager/hyprland/`
- **Design system tokens:** `modules/home-manager/design-system/`
- **Design system docs:** `docs/design-system/`
- **Battery PRD:** `.ai/prds/15-battery-management.md`
