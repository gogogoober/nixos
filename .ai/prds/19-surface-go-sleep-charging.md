# Surface Go 3 Sleep and Charging PRD

## Goal

Keep the Surface Go 3 charging reliably, and record what actually
causes the failure so the next occurrence is a two minute fix instead
of a diagnosis from scratch. Updated 2026-09-09 after a live failure
and recovery. The May 2026 diagnosis below was wrong on two counts and
is corrected here rather than deleted, because the wrong theory is
easy to arrive at twice.

## What Actually Happens

### The failure, observed 2026-09-09

The machine sat at 25 percent, plugged in, refusing to charge:

```
/sys/class/power_supply/ACAD/online   0
/sys/class/power_supply/BAT1/status   Not charging
upower state                          pending-charge, 0 W
```

A normal reboot did not clear it. The state survived a full shutdown
and cold boot, and the gas gauge kept falling while the charger was
connected.

### The fix

Holding volume-up plus power for roughly twenty seconds, releasing,
then powering on. That is the Surface firmware and embedded controller
reset. Immediately after:

```
ACAD/online   1
BAT1/status   Charging
upower        charging, 18.9 W, 54.9 minutes to full
```

### When it latched, from the boot logs

The kernel prints the adapter state once per boot, which gives an
exact record of when the EC stopped seeing the charger:

```
Sep 08 17:35  off-line
Sep 08 20:56  on-line
Sep 08 21:00  on-line
Sep 08 21:42  on-line      last healthy boot
Sep 08 22:06  off-line     latched here
Sep 09 08:59  off-line
Sep 09 10:52  off-line     survived a full cold boot
Sep 09 11:00  on-line      after the firmware reset
```

The 22:05 shutdown before it was clean, with no crash, no forced power
off, and no firmware update in the journal. The machine then suspended
overnight from 22:07 to 08:18 and drained, because it believed it was
on battery the entire time.

### Why the EC latched off, and what cannot be known

The embedded controller is a separate microcontroller running Microsoft
firmware. It owns adapter detection and charging, and it publishes a
single boolean to Linux through ACPI. It keeps its own state across an
OS reboot and writes no log that anything on this side can read, so the
triggering event is not recoverable after the fact.

What the evidence supports is that the state flipped across a clean
reboot while the charger was attached, and then never re-polled. The
Go 3 has an upstream ACPI quirk for exactly this family of behaviour,
because the model does not update its power state promptly when the
adapter is plugged or unplugged. The most likely trigger is a momentary
loss of contact or a charger renegotiation landing in the reboot
window, which the magnetic Surface Connect plug makes easy. If this
starts recurring, the cable and power supply are the first suspects,
not the software.

### Root cause

Embedded controller state. The EC stops reporting the adapter and a
soft reboot does not reset it, because the EC keeps power and state
across an OS restart. Only the two-button hold clears it.

### What this rules out

The repo config is not involved. There is no `services.tlp`, no charge
thresholds, and no power management beyond the hibernate lockout,
zram, and thermald. The Go 3 exposes no `charge_control_*` sysfs files
at all, so there is no software knob that could inhibit charging.

Hibernate is not the cause. Hibernate has been disabled on this host
since 2026-05-05 by this very document, and the failure happened
anyway. The lockout stays, but for a different reason: linux-surface
lists hibernate as unsupported on the Go 3.

The UCSI error is not the cause, but it is not unrelated either. An
earlier reading of this incident called it a red herring; the boot
logs say otherwise:

```
boot  -8  AC on-line    ucsi PPM init failures: 0
boot  -7  AC off-line   ucsi PPM init failures: 0   genuinely unplugged
boot  -6  AC on-line    ucsi PPM init failures: 0
boot  -5  AC on-line    ucsi PPM init failures: 0
boot  -4  AC on-line    ucsi PPM init failures: 0
boot  -3  AC off-line   ucsi PPM init failures: 1   latched
boot  -2  AC off-line   ucsi PPM init failures: 1   latched
boot  -1  AC off-line   ucsi PPM init failures: 1   latched
boot   0  AC on-line    ucsi PPM init failures: 0
```

Three for three inside the latched window, zero for six outside it,
including a healthy boot that was genuinely running on battery. That
reads as a second symptom of the same wedged controller rather than an
independent fault.

It still cannot be the cause. UCSI is a reporting and control
interface for the OS, and the power delivery contract is negotiated by
the controller in firmware, so a dead UCSI stack does not stop a
battery charging.

One caveat before treating the correlation as settled: on the current
healthy boot the driver is not bound to `USBC000:00` at all and logs
nothing, so a boot with zero failures may mean the probe never ran
rather than that it succeeded. Reloading `ucsi_acpi` by hand while the
machine is healthy would settle it.

## Recovery Runbook

1. Confirm the symptom: `cat /sys/class/power_supply/ACAD/online` and
   `cat /sys/class/power_supply/BAT1/status`. Zero and "Not charging"
   while plugged in is this failure.
2. Hold volume-up plus power for twenty seconds, release, power on.
3. If it still refuses, swap the charging path. Surface Connect and
   USB-C are independent power paths and only one is likely broken.
4. Charge with the machine powered off. A Go 3 charges roughly twice
   as fast off than in use.

## Detection

Nothing in software can clear the latch, since the controller only resets
when it loses power. What the config can do is notice the state and say
so, which turns a four hour discovery into a thirty second one.

`modules/nixos/charger-watch.nix` checks the fingerprint on resume, two
minutes after boot, and every twenty minutes after that, and raises a
critical desktop notification naming the volume-up plus power hold when
it matches. It clears its own warning marker as soon as the adapter is
seen again, so a single failure produces a single notification.

The check is deliberately narrow. Adapter off-line paired with a battery
that reports `Not charging` is the latch; adapter off-line paired with
`Discharging` is an ordinary unplugged machine and stays silent.

## Can It Be Fixed In Software, researched 2026-09-09

No. The reasoning is recorded here so the question does not get
reopened from scratch.

The kernel does not cache the adapter state. Every read of
`ACAD/online` evaluates the ACPI `_PSR` method afresh, and during the
failure that method returned zero on every read across three boots.
The firmware itself was reporting no adapter, so there is nothing a
driver patch could correct.

There is no software reset for the controller. Microsoft documents the
button hold as the recovery method, and linux-surface exposes no
equivalent. The Go 3 does not use the Surface Aggregator Module at
all, so `surface-control` and the aggregator drivers do not apply to
it either.

Upstream already carries the only Go 3 power quirk that exists: HID
`MSHW0146` with a battery notification delay, merged in 5.17 and
present in this kernel. It covers battery readings going stale right
after a plug or unplug, on the battery path only, and does nothing for
a latched adapter.

The nearest linux-surface report, issue 751, is a different failure.
That one was USB-PD negotiating twenty volts while drawing no current,
and reporters confirmed it resolved on 6.x kernels.

Firmware is already current at 17.103.143. Microsoft does not publish
to the LVFS, and the community capsule repository describes itself as
work in progress on an extremely locked down device with unknown
recovery from a bad flash. Taking that risk to reinstall the version
already running is not a trade worth making.

What remains implementable is detection, which is done. If this starts
recurring, the next suspect is physical: the cable, the connector, or
the power supply.

## Kernel Research, 2026-09-09

### This host has never run linux-surface

The earlier draft of this document claimed the device uses the
linux-surface kernel patches. It does not. `flake.nix` has no
`nixos-hardware` input and nothing in the tree sets
`boot.kernelPackages`, so this is the stock nixos-unstable kernel,
currently 6.18.50.

### What nixos-hardware would provide

`nixos-hardware` exports `microsoft-surface-common`,
`microsoft-surface-go`, `microsoft-surface-pro-intel`, and
`microsoft-surface-laptop-amd`. The common module pins a kernel built
from a linux-surface patch set, currently 6.19.8, and adds
`mem_sleep_default=deep`, IIO sensor support, redistributable
firmware, and optional `iptsd` and `surface-control`. TLP is
explicitly left disabled because it misbehaves on these machines.

### What the Go 3 actually gains

Per the linux-surface feature matrix, mainline already covers
touchscreen, wifi, bluetooth, speakers, suspend, sensors, and the
Type Cover keyboard and trackpad. Battery status needs 5.17 or newer,
and this host is well past that. The patched kernel adds pen input,
the hardware buttons, and performance mode switching. Cameras are
unsupported on the Go 3 under any kernel, and so is hibernate.

Nothing in that list touches charging.

### What it costs

There is no public binary cache for the patched Surface kernel, so it
builds locally. On hardware of this class that is three or more hours,
with a real out-of-memory risk on four threads and 8 GB, half of which
is committed to zram. Worse, `system.autoUpgrade` runs unattended
every Monday at 09:00, so every kernel bump upstream would kick off
that build on a fanless tablet that may be on battery at the time.

Two smaller mismatches: `microsoft-surface-go` targets the Go 1, with
Kaby Lake defaults and Atheros wifi firmware, while this is a Go 3 on
an i3-10100Y with Intel wifi, so the correct import would be
`microsoft-surface-common`. And the common module's
`mem_sleep_default=deep` is inert here, since `/sys/power/mem_sleep`
offers only `s2idle` on this device.

### Recommendation

Do not adopt it. It fixes nothing on the charging path, and the
recurring multi-hour unattended kernel build is a worse problem than
the one it would solve. Revisit only if pen input becomes a
requirement, and then only alongside a remote builder or a binary
cache so the weekly upgrade does not compile a kernel on the tablet.

## Changes Made

### 2026-05-05, kept

`power.nix` blocks all hibernate variants and `hypridle.nix` uses
plain `systemctl suspend` on the idle path. Both stay. The original
rationale, that hibernate causes the charging failure, is not
supported by evidence, but hibernate is unsupported on this model
regardless.

```nix
systemd.sleep.settings.Sleep = {
  AllowHibernation = false;
  AllowHybridSleep = false;
  AllowSuspendThenHibernate = false;
};
```

### 2026-09-09

Recovering the machine needed no code, only the firmware reset. The
runtime mitigation while it was stranded on battery was the backlight
down to 12 percent; GNOME was already on the power-saver profile, the
governor already on powersave, and bluetooth already soft-blocked.

Two changes came out of the incident:

- `modules/nixos/charger-watch.nix`, the latch detector described
  above, enabled on this host only.
- `modules/home-manager/hyprland/hypridle.nix` now gates on
  `modules.hyprland.enable`. It was the one file in that directory
  starting a daemon unconditionally, so on this GNOME host hypridle
  respawned every ten seconds forever, unable to bind
  `ext-idle-notifier-v1`. It had logged 115 restarts in under an hour
  of uptime.

## Out of Scope

- Adopting the linux-surface kernel. Researched and declined above.
- Camera support. Not achievable on the Go 3 on any kernel today.
- Battery charge thresholds. PRD 15 targets a different host, and this
  device exposes no threshold sysfs files.

## References

- **Power module:** `modules/nixos/power.nix`
- **Latch detector:** `modules/nixos/charger-watch.nix`
- **Idle policy:** `modules/home-manager/hyprland/hypridle.nix`
- **Auto upgrade timer:** `modules/nixos/common.nix:65`
- **AC sysfs:** `/sys/class/power_supply/ACAD/online`
- **Battery sysfs:** `/sys/class/power_supply/BAT1/status`
- **Sleep states:** `/sys/power/mem_sleep`
- **nixos-hardware surface modules:** github.com/NixOS/nixos-hardware/tree/master/microsoft/surface
- **linux-surface USB-PD report, different failure:** github.com/linux-surface/linux-surface/issues/751
- **Upstream Go 3 battery quirk patch:** lkml.iu.edu/2203.3/01682.html
- **Community firmware capsules, WIP:** github.com/linux-surface/surface-uefi-firmware
- **linux-surface feature matrix:** github.com/linux-surface/linux-surface/wiki/Supported-Devices-and-Features
- **Go 3 battery quirk, upstream since 5.17:** ACPI HID `MSHW0146`
