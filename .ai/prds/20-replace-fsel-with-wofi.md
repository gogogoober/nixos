# Replace fsel with wofi PRD

## Goal

Remove `fsel` as the Hyprland app launcher and use `wofi`, which is
already installed, already themed from the design system, and already
in use elsewhere in this config. The point is not that fsel is bad. It
is that fsel is the last third-party flake input in the tree, it has
no stable release branch to track, and it is the only reason the popup
host carries a second layout type.

## Why fsel is the odd one out

After moving the flake to `nixos-26.05`, every input points at a
stable ref except two:

- `nixpkgs-unstable`, which exists deliberately to keep `claude-code`
  current and feeds exactly one package.
- `fsel`, pinned to tag `3.7.0` because upstream has no release
  branch. It is a personal repo with no packaging in nixpkgs.

fsel also drags a build-time Rust toolchain behind it: `naersk` pulls
`fenix`, which tracks nightly Rust and its own nixpkgs. That subtree
is frozen inside fsel's lock so it does not drift, but it is three
extra lock nodes and a source build on every toolchain bump, for an
app launcher.

wofi is in nixpkgs, ships as a binary from the cache, and is already
declared in `modules/nixos/hyprland.nix`.

## What already exists

`modules/home-manager/hyprland/wofi.nix` writes a full `style.css` and
`config` for wofi, generated from the design system: colors, fonts,
radii, spacing, row height, focus borders. It is already the launcher
for the keybindings cheatsheet at `keybinds.nix:30`, which pipes into
`wofi --dmenu`. So wofi is not a new dependency or a new look. It is
an existing, styled component that is currently doing a smaller job
than it could.

The wofi config already sets `location=center`, `insensitive=true`,
and `hide_scroll=true`, which is the behaviour the fsel popup is
being hand-positioned to imitate.

## What changes

### 1. The launcher itself

Delete `modules/home-manager/hyprland/quick-popups/launcher.nix` and
its import in `quick-popups/../default.nix:24`.

The keybind at `keybinds.nix:76` moves from the popup host to wofi
directly:

```
"$mod, SPACE, App launcher, exec, wofi --show drun"
```

wofi needs to know how to run `Terminal=true` desktop entries, which
is what fsel's `terminal_launcher = "ghostty -e"` was doing. Add to
the wofi config in `wofi.nix`:

```
term=ghostty
```

### 2. The popup host loses a layout type

`quick-popups/host.nix` has a `type` enum of `quick-view` and
`launcher`, and a `typeGeometry` attrset with an entry for each. The
`launcher` type exists solely to center and size the ghostty window
that fsel runs inside. Nothing else in the tree sets
`type = "launcher"`; every other popup takes the `quick-view` default.

Once fsel is gone, remove from `host.nix`:

- the `launcher` branch of `typeGeometry` (`host.nix:44-47`)
- `"launcher"` from the `type` enum (`host.nix:198-201`)
- the `launcherWidth` binding (`host.nix:34`)
- the `launcher:` line from the `type` option description

The enum then has one member. Collapsing the option entirely is
tempting but out of scope, because a second quick-view geometry is a
plausible near-term addition and the option is what documents it.

### 3. The flake input

Remove the `fsel` input from `flake.nix`. This also drops `naersk`,
`fenix`, `rust-analyzer-src`, `flake-utils`, `systems`, and a nixpkgs
copy from `flake.lock`, leaving four inputs: `nixpkgs`,
`nixpkgs-unstable`, `flake-parts`, `home-manager`.

## What is lost

fsel has features wofi does not:

- **Pinning.** `ctrl+space` pins an app to the top of the list.
  wofi has no pinning; it sorts by use frequency instead, which
  covers the same need without the manual step.
- **Image preview.** `alt+i`. wofi shows icons but not previews.
- **Tagging.** `ctrl+t`. No wofi equivalent.

None of these appear in any keybind, script, or note in this repo
outside fsel's own default keybind table, which was copied verbatim
from upstream and never customised. That is the evidence that they are
unused, not proof, so it is the one thing worth confirming before the
change lands.

## Prior art in this repo

Walker was tried as an fsel replacement in `51cb49d` and reverted the
same morning in `5294e0b`, with no reason recorded in either message.
Whatever went wrong there is not written down. wofi is a different
proposition from walker: no new flake input, no new theming, already
running in this config. But the revert is a reminder to keep the
change small enough to back out in one commit.

## Verification

After rebuilding:

1. `$mod+SPACE` opens wofi centered, themed to match the cheatsheet.
2. Launching a terminal app (a `Terminal=true` desktop entry) opens it
   in ghostty rather than failing silently.
3. `hypr-popup` still works for every remaining popup: battery,
   bluetooth, volume, wifi, music.
4. The keybindings cheatsheet still opens and is styled identically.
5. `jq -r '.nodes | keys | length' flake.lock` drops by six.

## Rollback

One commit, one revert. Generation rollback from the boot menu covers
the rest.
