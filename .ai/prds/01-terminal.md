# Terminal Configuration PRD

## Goal
Replace Kitty with Ghostty as the default terminal, preserving the current
feel (JetBrainsMono Nerd Font, Tokyo Night, generous padding, silent bells)
and updating every place that currently shells out to `kitty`. Shell choice
(zsh vs. something else) is an open question — see Decisions.

## Current State

### Terminal: Kitty
`modules/home-manager/terminal.nix`, gated on `modules.terminal.enable`.

- Font: JetBrainsMono Nerd Font, size 12
- Theme: `tokyo_night_night`
- Tabs: powerline style, slanted
- Window padding: 8
- Scrollback: 10,000 lines
- Bells: fully silenced (audio, visual, tab, alert)

### Shell: Zsh + Starship
`modules/home-manager/shell.nix`, gated on `modules.shell.enable`.

- Zsh with autosuggestions, syntax highlighting, 10k dedup'd history
- Aliases: `ll=eza -la`, `tree=eza --tree`, `cat=bat`, `cd=z` (zoxide)
- `unsetopt BEEP`
- Starship prompt: two-line, directory + git branch + git status + prompt
  char, Nerd Font glyphs, custom substitutions for common folders

### NixOS-level wiring
- `programs.zsh.enable = true` in `modules/nixos/common.nix`
- `users.users.<name>.shell = pkgs.zsh` in both host files

### Hyprland keybinds referencing Kitty
`modules/home-manager/hyprland/keybinds.nix`

- Line 16: terminal-class match for per-app modifier routing, includes `kitty`
- Line 70: `Super+T` launches `kitty`
- Line 72: `Super+A` launches `kitty -e claude`

## References
_GitHub URLs and the specific parts we want from each._

- URL:
  - What to take:

## Proposed Changes
_Filled in once references land. Sketch of likely edits:_

- New `programs.ghostty` block in `modules/home-manager/terminal.nix`
  replacing the Kitty block, carrying over font/theme/padding/bell settings.
- Update the terminal-class match and the two launch bindings in
  `modules/home-manager/hyprland/keybinds.nix` to point at `ghostty`.
- Decide shell migration (see Decisions) and apply to `shell.nix`,
  `modules/nixos/common.nix`, and both host files if we change it.

## Target Files
- `modules/home-manager/terminal.nix`
- `modules/home-manager/hyprland/keybinds.nix`
- `modules/home-manager/shell.nix` _(if we change the shell)_
- `modules/nixos/common.nix` _(if we change the shell)_
- `hosts/dell-old/default.nix` _(if we change the shell)_
- `hosts/surface-go-3/default.nix` _(if we change the shell)_

## Decisions To Make
- Shell: stay on zsh, or move to fish/nushell/something else? Ghostty itself
  does not replace the shell, so this is a separate choice.
- Theme: keep Tokyo Night Night, or pick a Ghostty-native theme as part of
  the refresh?
- Ghostty config surface: use `programs.ghostty` via home-manager, or drop a
  config file into `~/.config/ghostty` using `xdg.configFile`?
