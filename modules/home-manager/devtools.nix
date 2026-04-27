{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.devtools;
in
{
  options.modules.devtools = {
    enable = mkEnableOption "personal developer tooling";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      lazygit # TUI git client
      claude-code # Anthropic's CLI coding agent
      just # Command runner, reads ./Justfile
      nixd # Nix LSP
      nixfmt # Nix formatter
      shfmt # Shell formatter
      shellcheck # Shell linter
      stylua # Lua formatter
      lua-language-server # Lua LSP
      prettier # Markdown, JSON, YAML, HTML, CSS, TS, JS formatter
      typos # Typo linter for code and prose
      typos-lsp # Editor LSP wrapper for typos
    ];
  };
}
