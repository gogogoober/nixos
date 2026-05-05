# Surface Go Sleep and Charging PRD

## Goal

Stop the Surface Go from losing charging ability after waking from
sleep. The device uses the linux-surface kernel patches and its USB-C
power delivery negotiation breaks when the system resumes from
hibernate. The fix is to disable all hibernate variants in systemd and
route hypridle through plain suspend instead.

## Current State

### Charging dies after hibernate resume

After the system wakes from hibernate or suspend-then-hibernate, the
USB-C charger stops delivering power. The Surface Go uses s2idle
(modern standby), not traditional S3 sleep. Hibernate involves
snapshotting RAM to swap and fully cutting power; on resume the USB-C
PD controller re-negotiates with the charger, and this handshake
fails under the linux-surface driver stack. The result is a machine
that wakes with a dead charge line even though the charger is plugged
in. Unplugging and replugging the charger restores it, but that is not
an acceptable normal state.

This is a known bug in the linux-surface project with no upstream fix
as of 2026. See the reference issue below.

### The previous sleep policy used suspend-then-hibernate

Hypridle was configured to call `systemctl suspend-then-hibernate`
after seven minutes idle. The systemd sleep config set
`HibernateDelaySec = 8m`, meaning the machine would hibernate roughly
fifteen minutes after going idle. Every hibernate cycle was a
potential charging failure on the next wake. The quick-settings Sleep
button already used plain suspend, so the power menu was safe but the
idle path was not.

## Changes Made

Both files were updated as part of the hard-reset recovery session on
2026-05-05.

### power.nix — block all hibernate variants

Replaced the `HibernateDelaySec` setting with explicit deny flags so
systemd cannot trigger any hibernate path regardless of caller:

```nix
systemd.sleep.settings.Sleep = {
  AllowHibernation = false;
  AllowHybridSleep = false;
  AllowSuspendThenHibernate = false;
};
```

### hypridle.nix — idle path uses plain suspend

Changed the idle listener timeout action from
`systemctl suspend-then-hibernate` to `systemctl suspend`. The
seven-minute timeout is unchanged.

## Tradeoffs

The only real loss is auto-hibernate on extended idle. If the Surface
Go is left suspended overnight it will drain the battery rather than
snapshotting to disk. Given that hibernation is the direct cause of
the charging failure, this is the right tradeoff. Suspend (s2idle)
keeps the charger handshake alive and wakes reliably.

If extended idle battery drain becomes a problem, the correct path is
to investigate whether the linux-surface project has patched the USB-C
resume issue rather than re-enabling hibernate and accepting broken
charging.

## References

- **power.nix:** `modules/nixos/power.nix`
- **hypridle.nix:** `modules/home-manager/hyprland/hypridle.nix`
- **linux-surface charging bug:** github.com/linux-surface/linux-surface/issues/1671
- **linux-surface suspend issue tracker:** github.com/linux-surface/linux-surface/issues/1515
- **NixOS sleep config docs:** wiki.nixos.org/wiki/Power_Management

## Out of Scope

- Re-enabling hibernate if linux-surface ships a fix. That is a
  separate change once the upstream bug is confirmed resolved.
- Swap partition sizing or swapfile configuration for hibernation.
  Hibernate is disabled; swap for hibernation is irrelevant until that
  changes.
- Battery threshold management. Covered in PRD 15.
