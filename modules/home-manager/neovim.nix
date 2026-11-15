{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.neovim;

  seedDir = ../../assets/nvim;
  seedInit = seedDir + "/init.lua";
  seedWithoutInit = lib.fileset.toSource {
    root = seedDir;
    fileset = lib.fileset.difference seedDir seedInit;
  };
in
{
  options.modules.neovim = {
    enable = mkEnableOption "Neovim with portable lua config" // {
      default = true;
    };
  };

  config = mkIf cfg.enable {
    programs.neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
      withPython3 = false; # No python plugins, drop provider
      withRuby = false; # No ruby plugins, drop provider
      initLua = lib.mkAfter (builtins.readFile seedInit); # Home Manager owns init.lua

      extraPackages = with pkgs; [
        bash-language-server # Bash LSP
        gopls # Go LSP
        marksman # Markdown LSP
        pyright # Python LSP
        rust-analyzer # Rust LSP
        tailwindcss-language-server # Tailwind LSP
        typescript-language-server # TS/JS/React LSP
        vscode-langservers-extracted # HTML/CSS/JSON/ESLint LSPs
        yaml-language-server # YAML LSP

        gofumpt # Go formatter
        ruff # Python linter and formatter

        fd # File finder used by telescope/fzf-lua
        nodejs # Runtime for JS-based LSPs
        ripgrep # Grep used by telescope/fzf-lua
        tree-sitter # Parser CLI
      ];
    };

    # Overlay a copy (not symlink), so lazy-lock.json and friends survive rebuilds.
    home.activation.copyNvimConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD mkdir -p "$HOME/.config/nvim"
      $DRY_RUN_CMD cp -rT ${seedWithoutInit} "$HOME/.config/nvim"
      $DRY_RUN_CMD chmod -R u+w "$HOME/.config/nvim"
    '';
  };
}
