# Battery Management PRD

## Goal
Make the laptop battery percentage trustworthy again and put charge
threshold management under nixos so it survives rebuilds. Today the
firmware's reported capacity is stale because BIOS-level charge
thresholds prevent the gas gauge from ever observing a real full or
empty event. The bar shows a percentage that is mathematically
correct against a stale baseline, which makes it feel jumpy and
unreliable. The fix is a one-time recalibration cycle plus a
declarative threshold policy in nixos so the regression does not
recur silently.

## Current State

### The gas gauge has lost the plot
`/sys/class/power_supply/BAT0` reports a design capacity of 4474 mAh
but a current "full" of 2796 mAh — about 62 percent of original. The
cycle counter still reads zero on a battery manufactured 2020-03-15,
which is the giveaway that the firmware has stopped re-learning.
Waybar's battery module reads `POWER_SUPPLY_CAPACITY` directly, so
its percentage tracks the stale baseline rather than real energy.

### Charge thresholds are set somewhere outside nixos
`charge_control_start_threshold` is 50 and `charge_control_end_threshold`
is 90 on this Dell host. Nothing in the repo writes those values, so
they are coming from BIOS defaults or a kernel module's built-in
policy. That means a rebuild cannot reason about them and they are
invisible to the rest of the config.

### No power management module in the repo
Searches across `modules/` and `hosts/` turn up no `services.tlp`,
no `services.upower`, no `powerManagement` block, and no
charge-threshold writes. The only battery-aware code is the waybar
battery module and the new battery popup that opens bottom.

## References

- **Battery sysfs root:** `/sys/class/power_supply/BAT0`
- **Threshold sysfs files:** `charge_control_start_threshold`,
  `charge_control_end_threshold`
- **Bar battery module:** `modules/home-manager/hyprland/bar.nix:205`
- **Battery popup:** `modules/home-manager/hyprland/quick-popups/battery.nix`
- **Companion PRD:** `12-status-indicators.md` (the bar module the
  user reads to judge battery state).

## Proposed Changes

### Add a tlp module under modules/system
A new `modules/system/power.nix` enables `services.tlp` and pins the
charge thresholds declaratively:

```nix
services.tlp = {
  enable = true;
  settings = {
    START_CHARGE_THRESH_BAT0 = 50;
    STOP_CHARGE_THRESH_BAT0 = 80;
  };
};
```

50/80 is the daily-use policy after calibration — slightly tighter
than the current 50/90 to slow further wear on a six-year-old cell.
The module is host-gated so non-laptop hosts (if any are added later)
do not pick it up.

### Document the calibration procedure in the module header
The module file gets a short top-of-file note pointing to a one-time
calibration sequence: temporarily widen the thresholds to 0/100,
charge to full and hold for an hour, discharge to shutdown, then
charge to full uninterrupted. After the firmware writes a new
`POWER_SUPPLY_CHARGE_FULL`, narrow the thresholds back. The note
exists so a future reader does not re-discover that tlp's pinned
thresholds prevent calibration if left at 50/80 forever.

### Surface real capacity in the popup, not just the bar
Bottom already shows live wattage draw. Add a brief note in the
battery popup file (or the PRD's follow-on) that `btm`'s Battery tab
is the canonical place to inspect health; the bar percentage is the
quick read. No code change required for v1 — just make the intent
explicit so future refactors do not strip the popup of its purpose.

## Open Questions

🟡 Should the tlp settings live on a per-host basis (e.g. only the
laptop host imports `power.nix`) or system-wide with an
`mkIf isLaptop` guard? The current repo pattern leans toward
per-host imports based on how `hosts/` is structured, but I have not
audited every module for the convention.

🟡 50/80 is the recommended tlp default for longevity, but it costs
roughly 20 percent of usable runtime versus 50/100. Is that the right
trade for this user's actual usage pattern, or should v1 ship 50/90
to match the current BIOS setting and only tighten later?

⚪ Worth considering `services.upower.enable = true;` alongside tlp?
upower gives userspace tools (and GNOME, when booted into it) a
cleaner view of battery state than raw sysfs. Cost is negligible.

## Out of Scope

- Replacing the physical battery. Calibration recovers accuracy, not
  capacity. A six-year-old cell at 62 percent of design will need
  hardware replacement eventually; that decision is outside this
  PRD.
- Power-profile switching (balanced / performance / power-saver).
  The bar's battery on-click was originally placeholdered for a
  profile picker. It now opens bottom; if a picker becomes desirable
  it should be its own popup, not bolted onto this PRD.
- GNOME-side power management. GNOME has its own power panel; this
  PRD is Hyprland-host-focused since that is now the primary DE per
  the recent switch.
