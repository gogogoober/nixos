# Quick Settings v2 PRD

## Goal
Replace v1's wofi dmenu with a reusable floating terminal host that
any top-nav icon can spawn. Each icon launches the host with a chosen
TUI inside it (impala for wifi, bluetuith for bluetooth, a music TUI,
and so on). The host dismisses on outside-click or Escape and cleans
itself up. Adding a new quick setting is a one-line launcher entry
plus a top-nav icon — never new UI code.

## Current State

### v1 ships a wofi dmenu
`modules/home-manager/hyprland/quick-settings.nix` provides
`hypr-quick-settings`, a single shell script with one wofi dmenu per
level. Wifi, Bluetooth, and Power are implemented and wired to the
waybar power button.

### Strong TUIs already exist for these settings
Wifi, bluetooth, and audio all have well-maintained TUIs that solve
the hard parts — full keyboard navigation, masked password input,
scan timing, error states — better than a hand-rolled wofi flow ever
will. v1's bespoke menus are worse versions of tools that already
exist in nixpkgs or upstream.

### No floating-terminal mechanism in the repo yet
There is no shared way to spawn a known-class floating terminal that
runs an arbitrary command and tears down on dismiss. Hyprland window
rules cover float/size/center; the rest needs to be built.

## References
- `pythops/impala` — wifi TUI
- `darkhz/bluetuith` — bluetooth TUI
- `tsowell/wiremix` or `pulsemixer` — audio TUI candidates

## Proposed Changes

### One reusable floating terminal host
A single mechanism opens a floating terminal with a known window
class, runs a given command inside it, and exits when the command
exits. Every quick setting reuses the same host. The host knows
nothing about wifi, bluetooth, or audio — it only knows how to spawn
a terminal, run a command, and clean up.

### Top-nav icons are the launcher
The waybar grows one icon per quick setting. Each icon's on-click
invokes the host with the matching TUI command. There is no central
menu and no parent surface — the icons are the menu, and each icon
opens directly into the tool that handles that setting.

### Two lifecycle modes
Each launcher entry declares whether its TUI is ephemeral or
persistent.

Ephemeral popups (wifi, bluetooth, audio) spawn fresh on each click,
exit on outside-click, Escape, or the TUI's own quit key. Nothing
survives between opens.

Persistent popups (music, anything that needs to keep running in the
background) spawn on first click and stay alive across dismissals.
Outside-click and Escape hide the window without killing the
process. Only the TUI's own quit key (typically `q`) actually exits
it. Clicking the icon again toggles the hidden popup back into view
rather than spawning a new one.

The lifecycle is a property of the launcher entry, not of the host
itself. The host knows how to spawn-and-kill and spawn-hide-toggle;
each entry picks one.

### Dismissal closes or hides
Outside-click and Escape are caught the same way regardless of mode;
the difference is only what they do — kill the window for ephemeral,
hide it for persistent. The TUI's own quit key always wins and
exits the process either way.

### Reusability is the architectural payoff
The mechanism is intentionally generic. Music, wifi, bluetooth, audio
output, and anything else with a usable TUI ride the same flow:
top-nav icon, reusable host, TUI, cleanup. This is what justifies
building a small system instead of hardcoding each tool's keybind.

## Decisions

### Terminal binary
Ghostty. Spawned with a dedicated `--class` so Hyprland window rules
can match it.

### Visual shape
Floating panel, fixed size, drawn over the content beneath it. Plain
rectangle, no parent chrome.

### Lifecycle
Spawn on top-nav icon click. Run the TUI inside a terminal with a
dedicated window class so Hyprland rules can match it. Dismiss on
outside-click or Escape. The terminal window closes when the TUI
inside exits, and process cleanup follows from that.

### Trigger surface
Top-nav (waybar) icons. No central quick-settings menu, no power
button rollup. Each setting gets its own icon.

### Reuse model
The host is a single command that takes the TUI invocation as its
argument. Adding a new quick setting is one launcher entry plus one
waybar icon — no changes to the host itself.

### One popup visible at a time
Only one popup is on screen at any moment. Clicking an icon while a
different popup is visible dismisses the current one and opens the
new one. This applies across modes — opening an ephemeral popup
hides any visible persistent popup, and vice versa. Persistent
popups that get hidden this way stay alive in the background; they
are only hidden, not killed.

### Persistent popups show a top-nav indicator
Every persistent popup running in the background shows a dot on its
top-nav icon. The dot reflects "process alive," not "window
visible," so a hidden-but-running spotify TUI still shows the dot.
The dot disappears when the TUI exits via its own quit key. The
exact glyph and color are a visual decision; the contract is that
the indicator state is driven by whether the persistent popup's
process is alive.

### Dismissing back to nothing
When an ephemeral popup is dismissed, the screen goes to nothing
even if a persistent popup was hidden underneath. Reflowing the
hidden persistent popup back into view on dismiss is surprising and
not worth the cleverness. To see the persistent popup again, click
its icon.

### Two window classes
Ephemeral and persistent popups use two distinct window classes so
Hyprland rules can target them independently. Lifecycle is read off
the class rather than off a title or workspace, which keeps the
rules legible and the keybinds scope-able.

### Audio TUI is wiremix
Wiremix is the audio TUI. No second candidate.

## Out of scope until decided

### Implementation details still open
- Whether the panel centers on screen or anchors under the clicked
  icon, and whether anchoring is worth the complexity
- Hide mechanism for persistent popups (Hyprland special workspaces
  are the obvious candidate but not the only option)
- Click-outside dismissal sidecar — likely a small process watching
  Hyprland IPC `activewindow` events, but the exact shape is open
- Escape dismissal mechanism — Hyprland keybind scoped to the popup
  class, kept distinct from the TUI's own keybindings
- How the top-nav indicator is wired — likely a state file or a
  signal the host writes on spawn/exit and waybar custom modules
  watch, but the exact seam is open
- Whether the v1 wofi power menu stays (lock, sleep, restart, shutdown
  do not need a TUI) or gets replaced by direct keybinds plus a
  small TUI wrapper

### Item scope
- Music TUI choice — not yet picked
- Power, brightness, DND treatment — no obvious TUI candidate and
  may stay as keybinds

## Target Files
_To be determined once terminal binary and dismissal mechanism are
settled._

## Status: Draft — direction committed, implementation details open
