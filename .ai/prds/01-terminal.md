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

- **cdalvaro/github-vscode-theme-iterm** (cloned into
  `.ai/references/github-vscode-theme-iterm`) — VSCode-accurate GitHub
  palette as iTerm2 `.itermcolors` plists. Source of truth for the Ghostty
  theme colors. File to use: `GitHub Dark Default.itermcolors`.
- **starship.rs/presets/nerd-font-symbols** — proposed Starship preset for
  git + language iconography.

## Proposed Changes

### Ghostty replaces Kitty
`modules/home-manager/terminal.nix` shrinks from 19 lines of Kitty config
to a single `programs.ghostty` block with three settings:

- `theme = "GitHub Dark Default"` (built-in, bundled from iterm2colorschemes)
- `font-family = "JetBrainsMono Nerd Font"` (already installed via `modules/nixos/desktop.nix`)
- `font-size = 12`

Every other Kitty setting (tabs, padding, scrollback, bell silencers) drops
to Ghostty defaults. No asset file needed.

### Starship moves to a preset
Strip the hand-written `format`, `directory`, `git_branch`, and
`git_status` blocks. Import the Starship **Nerd Font Symbols** preset,
pinned to `v1.25.0`, fetched via `pkgs.fetchurl` and converted with
`fromTOML`.

- Nerd Font icons across every module (git, languages, tools, cloud)
- Git branch + git status with glyphs
- Language detection icons based on files in the directory

### Zsh shrinks to essentials
Keep in `modules/home-manager/shell.nix`:

- `programs.zsh.enable`
- `autosuggestion.enable`
- `syntaxHighlighting.enable`
- History size + dedup
- Aliases (all kept — functional, not styling): `ll=eza -la`,
  `tree=eza --tree`, `cat=bat`, `cd=z`

Drop `unsetopt BEEP` (terminal handles bells).

### Fuzzy search stack already in place
No changes needed. For the record, already configured:

- `programs.fzf.enableZshIntegration` in `modules/home-manager/common.nix`
  — gives fzf-backed Ctrl-R history search, Ctrl-T file search, Alt-C dir
  jump
- `programs.zoxide.enableZshIntegration` in the same file — the `cd=z`
  alias drives zoxide
- `ripgrep` and `fzf` binaries in `modules/nixos/common.nix`
- `fzf-lua` picker in `modules/home-manager/lazy-nvf.nix` (Neovim side)

### Hyprland keybinds point at Ghostty
In `modules/home-manager/hyprland/keybinds.nix`:

- Terminal class match (line 16): replace `kitty` with Ghostty's class
  string (likely `com.mitchellh.ghostty`)
- Launch binding (line 70): `exec, ghostty`
- Claude binding (line 72): `exec, ghostty -e claude`

### Shell stays as zsh
No changes to `modules/nixos/common.nix` or the host files.

## Target Files
- `modules/home-manager/terminal.nix`
- `modules/home-manager/shell.nix`
- `modules/home-manager/hyprland/keybinds.nix`

## Status: Implemented

- Shell stays zsh
- Aliases stay (ll, tree, cat, cd)
- JetBrainsMono Nerd Font stays
- Fuzzy search stack unchanged (fzf, zoxide, ripgrep, fzf-lua already wired)
- Theme: `GitHub Dark Default` (built-in Ghostty theme, no asset file)
- Starship preset: Nerd Font Symbols, pinned to `v1.25.0`
- Net line change: 66 deletions, 13 insertions across three files
