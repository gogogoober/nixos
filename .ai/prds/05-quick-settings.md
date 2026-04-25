# Quick Settings Configuration PRD

## Goal
Replace the existing standalone power menu with a single navigable wofi
menu, `hypr-quick-settings`, that opens from the waybar power button and
exposes wifi, bluetooth, and power as a tree of dmenu lists. Each row
either drills into another list, opens a masked or plain text input, or
runs an action and closes. Audio output and do not disturb are deferred
to a follow-up; this PRD ships the three branches that pay for the
infrastructure.

## Current State

### Power menu is its own script
`modules/home-manager/hyprland/overlay.nix` defines `hypr-power-menu`,
a wofi dmenu with Lock, Suspend, Reboot, Shutdown. Wired to the waybar
power button via `on-click = "hypr-power-menu"` in
`modules/home-manager/hyprland/bar.nix:66`.

### Quick settings module is empty
`modules/home-manager/hyprland/quick-settings.nix` is a no-op `mkIf`
block with no body.

### Wofi menu pattern is established
Three precedents already in the repo, all `pkgs.writeShellScriptBin`
shelling out to `wofi --dmenu`:
- `hypr-app-drawer` (overlay.nix:12)
- `hypr-power-menu` (overlay.nix:16)
- `hypr-cheatsheet` (keybinds.nix:27)

### Backing tools available
- `nmcli` via `networking.networkmanager.enable` in `modules/nixos/common.nix:55`
- `bluetoothctl` via `hardware.bluetooth.enable` in `modules/nixos/desktop.nix:53`
- `hyprlock` and `systemctl` already used by the existing power menu

## References
_None yet — we are writing this from scratch using the existing wofi
script pattern in this repo as the template._

## Proposed Changes

### One script, dispatched by argument
`modules/home-manager/hyprland/quick-settings.nix` defines
`hypr-quick-settings` as a `pkgs.writeShellScriptBin`. The script takes
an optional first argument naming the level to render; with no argument
it shows the top-level list. Each sub-list re-invokes the same binary
with a sub-argument so back navigation is just another exec.

### Top-level list
Three rows, in this order:
- Wifi
- Bluetooth
- Power

### Wifi branch
`hypr-quick-settings wifi` triggers a rescan with
`nmcli device wifi rescan` (or `--rescan yes` on the list call), then
lists visible networks via
`nmcli -t -f SSID,SIGNAL,SECURITY device wifi list`, formatted as
`{ssid}  {signal}%  {🔒|·}`. Picking an open network calls
`nmcli device wifi connect <ssid>`.

Picking a secured network opens a second wofi prompt invoked with
`--password` to mask input. The password is piped to nmcli over
standard input rather than passed on the command line, using
`printf '%s\n' "$pw" | nmcli --ask device wifi connect <ssid>`. This
keeps the password out of the process list and shell history.

Hidden networks are out of scope for v1.

### Bluetooth branch
`hypr-quick-settings bluetooth` starts a timed discovery scan with
`bluetoothctl --timeout 8 scan on` in the background so unpaired
devices appear, then lists devices from `bluetoothctl devices` (paired)
unioned with `bluetoothctl devices Discovered` if available, dedup'd
by MAC. Each row shows the device name and a connection-state glyph
derived from `bluetoothctl info <mac>`.

Selecting a device opens a third-level action list whose contents
depend on the device's current pairing and connection state:

- Unpaired: Pair, Cancel
- Paired but not connected: Connect, Forget, Cancel
- Paired and connected: Disconnect, Forget, Cancel

Pair runs `bluetoothctl pair <mac>` then immediately `connect <mac>`
on success. Connect, Disconnect, and Forget run their matching
`bluetoothctl` commands directly.

### Power branch
`hypr-quick-settings power` is a four-row list: Lock, Sleep, Restart,
Shutdown. Lock calls `hyprlock`, Sleep calls `systemctl suspend`,
Restart calls `systemctl reboot`, Shutdown calls `systemctl poweroff`.
This subsumes the standalone `hypr-power-menu` entirely.

### Back navigation
Every sub-list has a `← Back` row at the top that re-execs
`hypr-quick-settings` with the argument that opens its parent level.
For one-deep branches (Wifi, Power) that is no argument, returning to
the top. For the bluetooth device action list (two deep) that is
`bluetooth`, returning to the device list rather than all the way out.
Escape from wofi closes the menu cleanly at any level.

### Waybar wiring
`modules/home-manager/hyprland/bar.nix:66` changes from
`on-click = "hypr-power-menu"` to `on-click = "hypr-quick-settings"`.

### Remove the old power menu
`hyprPowerMenu` is deleted from `modules/home-manager/hyprland/overlay.nix`
along with its entry in `home.packages`. No keybind currently points at
it, so no other call sites need updating.

## Decisions

### Keybind
None in v1. Entry point is the waybar power button click. A Super+S
keybind can be added later in `keybinds.nix` if the click feels slow.

### Out of scope for v1
- Audio output sink switching (deferred to follow-up)
- Do not disturb toggle (deferred; mako has no modes configured yet)
- Volume level slider (keyboard media keys handle this)
- Brightness level slider (keyboard media keys handle this)
- Power profiles (not currently used)
- Display arrangement and resolution
- Hidden wifi networks

## Target Files
- `modules/home-manager/hyprland/quick-settings.nix` — new
  `hypr-quick-settings` script and home.packages entry
- `modules/home-manager/hyprland/overlay.nix` — remove
  `hyprPowerMenu` and its packages entry
- `modules/home-manager/hyprland/bar.nix` — change waybar power button
  on-click target

## Status: Draft
