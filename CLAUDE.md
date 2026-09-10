# Repo Notes

## Surface Go 3 charging latch

If this host reports no charger while it is plugged in, it is almost never the
config. The embedded controller latches into a no-adapter state and holds it
across a normal reboot, because a soft restart never cuts EC power. Holding
volume-up + power for 20 seconds clears it.

Fingerprint: `/sys/class/power_supply/ACAD/online` reads 0 while
`/sys/class/power_supply/BAT1/status` reads `Not charging`. A genuinely
unplugged machine reads `Discharging` instead.

Known dead ends, already investigated:

- `ucsi_acpi ... PPM init failed` tracks the latch rather than causing it: three
  for three on latched boots, zero for six on healthy ones. It is a reporting
  interface, and charging is negotiated in firmware.
- Hibernate is disabled and was never the cause.
- The linux-surface kernel adds pen, buttons, and performance modes on this
  model, nothing on the charging path, and costs a 3+ hour local build with no
  binary cache.

Full write-up in `.ai/prds/19-surface-go-sleep-charging.md`;
`modules/nixos/charger-watch.nix` raises a desktop notification when the
fingerprint appears.

## Harmless ACPI error storm under load

Under sustained CPU load this host logs `Could not resolve symbol [\_TZ.TZ00]`
and `Aborting method \_SB.PCI0.LPCB.EC0._Q14` every six seconds or so, tapering
off as it cools. It is a firmware bug and it is benign: `_Q14` does nothing but
`Notify (\_TZ.TZ00, 0x80)`, and the DSDT declares that zone `External` while no
loaded SSDT defines it. The zones that do exist are `\_SB.PCI0.LPCB.TZ01`
through `TZ05`.

Not caused by thermald: the aborts still fire with the service stopped. Nothing
to fix, and unrelated to charging.

## Bootloader refuses to downgrade after a channel move

Moving to an older nixpkgs (unstable back to a stable release) builds fine and
then dies on the last step with `Failed to install bootloader`. The ESP holds a
newer systemd-boot than the release ships, and `bootctl update` will not go
backwards, so it skips both `.efi` files and exits non-zero. Nothing has
activated at that point, and the half-built generation has no boot entry.

Rerun with `--install-bootloader`, which forces `bootctl install` instead of
`update`: `just extra=--install-bootloader rebuild "<message>"`.

If every later rebuild fails the same way, with `updating systemd-boot from
260.1 to 260.2` followed by `same boot loader version in place already`, the
cause is a stale `EFI/systemd/systemd-boot-fallbackx64.efi`. systemd 261's
`bootctl` writes that fallback copy, and older releases never touch it. The
NixOS installer takes the first version `bootctl status` lists, which is the
fallback, so it requests an update that has nothing to do. Delete it once:
`sudo rm /boot/EFI/systemd/systemd-boot-fallbackx64.efi`.
