# surface-go-3

Microsoft Surface Go 3 tablet. GNOME, touch-first, and the machine this repo
is usually edited from.

## Goal

**Battery life first.** This is a fanless 8 GB tablet with a 3500 mAh cell, so
every change should be weighed against idle draw, thermal headroom, and how
much unattended CPU work it invites. A feature that costs meaningful watts
needs to earn its place.

Second goal: usable by touch alone, keyboard detached. That work is mostly
unstarted, see PRD 16.

When a change would help one host and hurt this one, gate it per-host rather
than putting it in a shared module.

## Hardware

| | |
| --- | --- |
| CPU | Intel i3-10100Y, Amber Lake-Y, 2 cores / 4 threads, 1.30 GHz, fanless |
| RAM | 8 GB, no expansion |
| Swap | zram at 50 percent of RAM, plus the disk partition, ~12 GiB total |
| Disk | 108 GiB root on NVMe, 1 GiB ESP |
| Battery | `BAT1`, 3500 mAh design |
| Adapter | `ACAD`, Surface Connect, magnetic |
| Sleep | `s2idle` only, `deep` is not offered |
| Kernel | stock nixpkgs, currently 6.18.50 |

The device does **not** use the Surface Aggregator Module, so `surface-control`
and the aggregator drivers do not apply. There is no `nixos-hardware` input and
nothing sets `boot.kernelPackages`; this is the plain nixpkgs kernel.

The battery and adapter are `BAT1` and `ACAD` here, not the `BAT0`/`AC0` most
guides assume. Anything reading sysfs directly needs the right names.

## What is turned on

From `hosts/surface-go-3/default.nix`:

- `common`, `desktop`, `gnome`, `developer`, `touchscreen` — the daily driver stack
- `hyprland` off; GNOME is the only session on this host
- `tts` and `stt` on, tuned small (see Speech below)
- `gaming` on, which is optimistic on this GPU but costs nothing idle
- `chargerWatch` on, and it is enabled **here only**

`power` and `firefox` default to true and are not listed.

## Power and battery posture

Already in place, do not undo without a reason:

- **No hibernate in any form.** `modules/nixos/power.nix` blocks hibernation,
  hybrid sleep, and suspend-then-hibernate. linux-surface lists hibernate as
  unsupported on this model.
- **zram, not disk-first swap.** zstd at 50 percent of RAM, which matters on
  8 GB with a browser and a language model server resident.
- **thermald on**, because a fanless chassis throttles rather than spins up.
- **Nix builds run at idle priority**, `max-jobs = 1`, so a rebuild does not
  make the tablet unusable.
- **The weekly auto-upgrade skips battery.** `nixos-upgrade` carries
  `ConditionACPower = true`, so a Monday 09:00 upgrade on battery waits for
  the next Monday rather than compiling on the cell.
- **GNOME suspends after 7 minutes** on both AC and battery.

- **The package power limit is capped per power profile.**
  `modules/nixos/intel-power-limit.nix` watches the active power-profiles-daemon
  profile over D-Bus and writes the matching RAPL limits: power-saver 5/10,
  balanced 5/15, performance 9/20 (sustained/burst watts). Firmware ships this
  5 W part at 15 W sustained and 24 W burst, which it cannot thermally hold, so
  it boosted into a throttle instead of running steadily.

  Measured plateaus under 75 s of all-core load, against a 100 °C limit:

  | Sustained | Die temp | All-core clock | Throttle events |
  | --- | --- | --- | --- |
  | 7 W | 71 °C | — | 0 |
  | 8 W | 65 °C | 2299 MHz | 0 |
  | 9 W | 72 °C | 2499 MHz | 0 |
  | 10 W | 91 °C | 2800 MHz | 10 |

  The curve goes vertical after 9 W, so that is where performance sits. Burst
  stayed at 20 W for every run and never caused a throttle, because burst only
  governs the opening window and the plateau is set by the sustained limit.

  Firmware reclaims the sustained register roughly a minute after boot, and
  probably after resume too. The write itself succeeds and verifies, so the
  service logs success and only a later read shows 15 W back in place. The
  watcher therefore rechecks every 60 s for the first 5 minutes after it starts,
  and the resume unit restarts it so waking gets a fresh window. It stays silent
  when the registers already match, so a journal line means something actually
  moved. Only the sustained limit gets reclaimed — burst survives untouched.

  The window is deliberately bounded. Drift outside the first few minutes has
  never been observed, and if it ever is, that is a different fault needing a
  different fix rather than a longer poll. It would surface as the watcher
  logging a re-application on the next profile switch.

  Chassis skin temperature is far below the die: with the die at 94 °C the board
  sensors read 53 °C and the case merely feels warm. That gap is normal for a
  fanless design and is not a sign the reading is wrong.

Not available on this hardware:

- **No charge thresholds.** The Go 3 exposes no `charge_control_*` sysfs files
  at all, so the 50/80 style policy in PRD 15 cannot be applied here. That PRD
  targets the Dell.
- **TLP is not used** and should stay out; the linux-surface project reports it
  misbehaving on these machines.

## The charging latch

The single most important failure on this machine. Full write-up in
`.ai/prds/19-surface-go-sleep-charging.md`.

**Symptom.** Plugged in, not charging, battery draining.

```
/sys/class/power_supply/ACAD/online   0
/sys/class/power_supply/BAT1/status   Not charging
```

A genuinely unplugged machine reads `Discharging` instead. That one word is the
whole diagnosis.

**Fix.** Hold volume-up plus power for twenty seconds, release, power on. That
is the Surface firmware and embedded controller reset.

**Cause.** The embedded controller is a separate microcontroller running
Microsoft firmware. It owns adapter detection, publishes one boolean to Linux
through ACPI `_PSR`, keeps power and state across an OS reboot, and writes no
log. It stops reporting the adapter and never re-polls. A soft reboot, and even
a full cold boot, does not clear it.

**It is never the config.** Every read of `ACAD/online` re-evaluates `_PSR`, so
the firmware itself is reporting no adapter. No driver patch or Nix option can
correct that. If it starts recurring, suspect the cable, the connector, or the
power supply, not this repo.

**Detection.** `modules/nixos/charger-watch.nix` checks the fingerprint two
minutes after boot, on resume, and every twenty minutes, and raises a critical
notification naming the button hold. It clears its marker when the adapter
comes back so one failure produces one notification.

**Dead ends, already investigated.** Do not reopen these without new evidence:

- `ucsi_acpi ... PPM init failed` correlates with the latch, three for three
  inside the window and zero for six outside, but cannot cause it. UCSI is a
  reporting interface and the power contract is negotiated in firmware.
- Hibernate was the original theory in May 2026. It was wrong; the failure
  happened with hibernate already disabled.
- Firmware is current at 17.103.143, Microsoft does not publish to LVFS, and
  the community capsule repo is work-in-progress on a locked-down device.

## The linux-surface kernel, declined

Researched and rejected 2026-09-09. It adds pen input, hardware buttons, and
performance mode switching, none of which touch charging. Mainline already
covers touchscreen, wifi, bluetooth, audio, suspend, sensors, and the Type
Cover. The cost is a 3+ hour local build with no binary cache, on four threads
and 8 GB, kicked off by the unattended weekly upgrade on every kernel bump.

Revisit only if pen input becomes a requirement, and only alongside a remote
builder or binary cache. The correct import would be
`microsoft-surface-common`, not `microsoft-surface-go`, which targets the Go 1.

## The ACPI error storm, was a symptom

Under sustained CPU load the journal used to fill with:

```
Could not resolve symbol [\_TZ.TZ00]
Aborting method \_SB.PCI0.LPCB.EC0._Q14
```

The abort itself is a harmless firmware bug: `_Q14` does nothing but
`Notify (\_TZ.TZ00, 0x80)`, and the DSDT declares that zone `External` while no
loaded SSDT defines it. The real zones are `\_SB.PCI0.LPCB.TZ01` through `TZ05`.
Not caused by thermald; the aborts fired with it stopped.

What was wrong was the earlier conclusion that there was nothing to fix. The
storm was the thermal zone notification firing while the machine cooked itself
against the 15 W firmware power limit, which is why it always tracked load and
tapered as the machine cooled. Capping the package (below) stopped it: zero
aborts since, including through deliberate all-core load tests that would
previously have set it off.

## Touchscreen

`modules/nixos/touchscreen.nix` enables IIO sensors and libwacom udev rules,
and ships a `touchscreen-fix` command bound to Alt+Shift+T in GNOME.

The regression it works around: re-attaching the Type Cover renumbers the USB
device and `hid_multitouch` loses the touchscreen. The fix reloads the module,
via a NOPASSWD sudo rule scoped to that one script.

Palm rejection on the touchscreen itself cannot be improved from config; the
ELAN9038 reports no `MT_TOOL_TYPE`.

## Type Cover touchpad, disable-while-typing missing

Not yet applied. The touchpad (`usb 045e:09b5`, "Microsoft Surface Keyboard
Touchpad") sits on a port that reports `removable`, so systemd's
`65-integration.rules` tags it `ID_INPUT_TOUCHPAD_INTEGRATION=external` and
libinput then skips DWT and all palm detection. `libinput list-devices` shows
`Disable-w-typing: n/a` and GNOME's toggle does nothing.

Preferred fix, the same mechanism upstream systemd used for the Surface Pro
cover `045e:09c0`, goes in `hosts/surface-go-3/default.nix` since `hardware.nix`
is generated:

```nix
services.udev.extraHwdb = ''
  touchpad:usb:v045ep09b5:name:Microsoft Surface Keyboard Touchpad:*
   ID_INPUT_TOUCHPAD_INTEGRATION=internal
'';
```

Reboot, then confirm `libinput list-devices` reports `Disable-w-typing:
enabled`. Drop the entry once systemd ships one for `09b5`.

## Speech

Both the TTS and STT daemons run resident on this host, sized for it:

- **STT** is whisper.cpp with `ggml-tiny.en` at 2 threads. Two, not four:
  hyperthreading hurts more than it helps on this chip. Bump to `base.en` only
  if accuracy actually becomes a problem.
- **TTS** is a Piper HTTP daemon keeping `en_US-lessac-medium` warm in memory,
  at 0.85 length scale.
- **Dev mode is off here.** `tts.devMode` is only set on the Dell, so logging
  and lifecycle notifications stay quiet on this host.

The keyboard shortcuts for both were removed in generation 34. Control now
lives in the `speech-panel` GNOME shell extension
(`modules/nixos/scripts/speech-panel/`), which puts dictate and speak toggles
in the top bar and colours them from the state files under `$XDG_RUNTIME_DIR`.
That was a deliberate touch-first move; do not put the Alt+Escape bindings back
without asking.

## Open work

- PRD 16, touch-only GNOME: on-screen keyboard, detached-keyboard detection,
  large-target launcher, auto-rotation. Mostly unstarted.
- The Type Cover hwdb entry above.

## References

- **Host switchboard:** `hosts/surface-go-3/default.nix`
- **Generated hardware:** `hosts/surface-go-3/hardware.nix`
- **Latch detector:** `modules/nixos/charger-watch.nix`
- **Power policy:** `modules/nixos/power.nix`
- **Touchscreen reset:** `modules/nixos/touchscreen.nix`
- **GNOME dconf and keybinds:** `modules/home-manager/gnome.nix`
- **Speech panel extension:** `modules/nixos/scripts/speech-panel/`
- **Charging PRD:** `.ai/prds/19-surface-go-sleep-charging.md`
- **Touch PRD:** `.ai/prds/16-touchscreen-gnome.md`
- **linux-surface feature matrix:** https://github.com/linux-surface/linux-surface/wiki/Supported-Devices-and-Features
