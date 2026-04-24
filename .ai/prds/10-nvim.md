# Neovim Configuration PRD

## Goal
Land on the best possible Neovim setup for this machine, delivered through
NVF. "Best" needs a real definition before we touch code — see Open
Questions. The outcome may be an incremental upgrade of the existing
`lazy-nvf.nix` module, or a full rewrite against a different NVF shape
(e.g. a LazyVim preset, a Kickstart-style rewrite, or a hand-rolled
minimal core). That decision is the first thing this PRD needs to resolve.

## Current State

### Module: `modules/home-manager/lazy-nvf.nix`
Gated on `modules.lazy-nvf.enable`, defaulted to `true`, imported from
`modules/home-manager/default.nix` and enabled for the user in
`home/hugo/default.nix`.

### Flake input
`nvf = { url = "github:notashelf/nvf"; }` in `flake.nix` at line 21.
No pinned rev; we track the flake's default branch via `flake.lock`.

### Module options exposed today
- `colorscheme` — string, default `"dracula"`. Must match an extraPlugin
  or a native nvf theme.
- `picker` — enum `fzf-lua | telescope`, default `fzf-lua`. Drives keymap
  and LSP action wiring.
- `autoOpenTree` — bool, default `false`. Opens neo-tree on directory
  launch via a `VimEnter` autocmd.

### What the module enables today
A fairly LazyVim-shaped stack:

- **Editor basics:** leader=space, 2-space indent, relative numbers,
  undofile, clipboard=unnamedplus, mouse=a, scrolloff=8, sensible
  timeouts, `viAlias` + `vimAlias`.
- **Theme:** Dracula via `pkgs.vimPlugins.dracula-nvim` as an extraPlugin,
  because nvf has no native Dracula. Native `theme.enable = false` so the
  extraPlugin drives it.
- **Languages with treesitter, format-on-save, and extra diagnostics:**
  typescript (JS/TS/React), nix, lua, bash, markdown, html, css, python,
  go, rust, yaml, json.
- **Picker:** fzf-lua at the `default` profile; telescope disabled.
- **File tree:** neo-tree, left-side, width 35, git status and
  diagnostics on, follows current file, hides gitignored but shows
  dotfiles, uses libuv watcher.
- **Treesitter:** folds, context, indent, textobjects.
- **LSP:** format-on-save, lspkind, lightbulb, trouble,
  tailwindcss-language-server preset, otter-nvim. Adds a manual
  `typos_lsp` server wired across most of the filetype list.
- **Completion:** blink-cmp with default keymap, auto docs, signature.
- **Snippets:** luasnip.
- **Git:** gitsigns with code actions.
- **Visuals:** devicons, indent-blankline, fidget, highlight-undo,
  rainbow-delimiters.
- **Statusline / tabline:** lualine (`theme = "auto"`), bufferline.
- **UI:** borders, noice, colorizer, illuminate, breadcrumbs,
  smartcolumn, fastaction, nvim-ufo.
- **Binds UI:** which-key, cheatsheet.
- **Utility:** flash-nvim motion, surround, nvim-biscuits, snacks-nvim,
  undotree, aerial outline.
- **Notes:** todo-comments.
- **Terminal:** toggleterm with lazygit integration.
- **Dashboard:** alpha.
- **Keymaps:** ~35 keybinds covering file nav, tree, buffer/window nav,
  LSP, diagnostics, git, terminal, save/quit, clear highlight. Picker
  bindings branch on `cfg.picker`.

### What we rely on downstream
- `fzf-lua` picker referenced by `.ai/prds/01-terminal.md` as part of the
  already-in-place fuzzy stack — any picker change should preserve that.
- Aerial/trouble/noice overlap in how diagnostics and UI float; a rewrite
  would need to decide which of those stay.

## References
_GitHub URLs and the specific parts we want from each. Fill in after we
decide direction._

- **NVF docs / module options:** https://notashelf.github.io/nvf/options.html
  - What to take: the canonical option names, and any newer modules
    (e.g. newer LSP servers, dap, copilot) we are not using yet.
- **NVF repo:** https://github.com/notashelf/nvf
  - What to take: the `configs/` examples and the LazyVim-equivalent
    preset, if one exists, for comparison against our hand-rolled set.
- **LazyVim:** https://www.lazyvim.org/
  - What to take: the default keymap table and which plugins ship in the
    base distro, as the yardstick for "upgrade vs rewrite."
- _(Optional)_ **kickstart.nvim:** https://github.com/nvim-lua/kickstart.nvim
  - What to take: minimal-core philosophy, for the rewrite path.

## Proposed Changes
_Blocked on Open Questions below. Once direction is decided, this section
gets concrete edits scoped to Target Files._

Sketch of the two plausible paths so we can pressure-test them:

### Path A: Incremental Upgrade
Keep `lazy-nvf.nix` as the single source. Audit the current enable-list
against the latest NVF options, turn on what is missing and worth having
(e.g. dap, copilot/codecompanion, newer LSP presets), prune anything
redundant (lspsaga/lspSignature already off; revisit illuminate vs
treesitter context overlap), and tighten keymaps. Net change is small
and reversible.

### Path B: Rewrite
Replace `lazy-nvf.nix` with a cleaner structure — likely split into a
small `nvim/` directory with `core.nix`, `lsp.nix`, `ui.nix`,
`keymaps.nix`, and a top-level module that imports them. Decide up front
whether to lean on an NVF preset (if one matches) or stay fully
declarative. Drop Dracula as an extraPlugin if we pick a theme NVF
supports natively.

> Pushback on rewriting for its own sake. The current module is ~525
> lines of fairly readable declarative config. Unless we land a concrete
> list of things the current shape prevents, a rewrite is motion without
> progress.

## Target Files
- `modules/home-manager/lazy-nvf.nix` — the module itself.
- `modules/home-manager/default.nix` — import line if we rename or
  split into `nvim/`.
- `home/hugo/default.nix` — enable flag if we rename the option.
- `flake.nix` — only if we pin NVF to a rev or swap inputs.
- `.ai/prds/01-terminal.md` — cross-reference to `fzf-lua` may need an
  update if the picker changes.

## Open Questions
🔴 What does "best" mean here? Candidate axes, pick which matter:
  startup time, LSP/completion quality, AI integration (copilot,
  codecompanion, avante), debugging (dap), notebook/REPL support,
  language coverage beyond what we have, keymap ergonomics, looks.

🔴 Upgrade or rewrite? Needs a concrete blocker list before rewrite
  wins on merit.

🟡 Theme: stay on Dracula, or switch to a native NVF theme to drop the
  extraPlugin?

🟡 Picker: fzf-lua is the current default and already referenced by
  the terminal PRD. Any reason to reconsider?

🟡 Should we pin NVF to a specific rev in `flake.nix` to avoid
  surprise breakage, or stay on the default branch?

⚪ Rename `modules.lazy-nvf` to `modules.nvim`? The `lazy-` prefix is
  historical and no longer reflects what the module does.

## Status: Drafting
Nothing merged yet. Next step is answering the Open Questions, then
filling in Proposed Changes concretely.
