{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.modules.editors;
in
{
  options.modules.editors = {
    enable = mkEnableOption "baseline editors (vim and VSCode)" // {
      default = true;
    };

    vscode.enable = mkOption {
      type = types.bool;
      default = true;
      description = "Install and configure VSCode with sensible defaults.";
    };
  };

  config = mkIf cfg.enable {
    # Plain vim as universal fallback - light, always works, zero config surprises
    programs.vim = {
      enable = true;
      defaultEditor = false;   # nvf's neovim wins when both are installed
      settings = {
        number = true;
        relativenumber = true;
        tabstop = 2;
        shiftwidth = 2;
        expandtab = true;
        ignorecase = true;
        smartcase = true;
      };
      extraConfig = ''
        syntax on
        set mouse=a
        set clipboard=unnamedplus
      '';
    };

    # VSCode with FHS wrapping so extensions with bundled binaries work on NixOS
    programs.vscode = mkIf cfg.vscode.enable {
      enable = true;
      package = pkgs.vscode-fhs;

      profiles.default = {
        extensions = with pkgs.vscode-extensions; [
          # Theme
          enkia.tokyo-night

          # Formatters
          esbenp.prettier-vscode

          # Language support
          bradlc.vscode-tailwindcss
          ms-python.python
          rust-lang.rust-analyzer
          golang.go
          jnoortheen.nix-ide
          angular.ng-template

          # Git
          eamodio.gitlens

          # Quality of life
          usernamehw.errorlens
          christian-kohler.path-intellisense
          editorconfig.editorconfig
        ];

        userSettings = {
          # Appearance
          "workbench.colorTheme" = "Tokyo Night";
          "editor.fontFamily" = "'JetBrainsMono Nerd Font', monospace";
          "editor.fontSize" = 13;
          "editor.fontLigatures" = true;
          "terminal.integrated.fontFamily" = "'JetBrainsMono Nerd Font'";

          # Format on save - the whole reason this module exists
          "editor.formatOnSave" = true;
          "editor.formatOnPaste" = false;
          "editor.codeActionsOnSave" = {
            "source.fixAll" = "explicit";
            "source.organizeImports" = "explicit";
          };

          # Prettier as default formatter for JS/TS/JSON/CSS/HTML/Markdown
          "[javascript]"."editor.defaultFormatter" = "esbenp.prettier-vscode";
          "[typescript]"."editor.defaultFormatter" = "esbenp.prettier-vscode";
          "[javascriptreact]"."editor.defaultFormatter" = "esbenp.prettier-vscode";
          "[typescriptreact]"."editor.defaultFormatter" = "esbenp.prettier-vscode";
          "[json]"."editor.defaultFormatter" = "esbenp.prettier-vscode";
          "[jsonc]"."editor.defaultFormatter" = "esbenp.prettier-vscode";
          "[css]"."editor.defaultFormatter" = "esbenp.prettier-vscode";
          "[scss]"."editor.defaultFormatter" = "esbenp.prettier-vscode";
          "[html]"."editor.defaultFormatter" = "esbenp.prettier-vscode";
          "[markdown]"."editor.defaultFormatter" = "esbenp.prettier-vscode";
          "[yaml]"."editor.defaultFormatter" = "esbenp.prettier-vscode";

          # Language-specific formatters
          "[nix]"."editor.defaultFormatter" = "jnoortheen.nix-ide";
          "[python]"."editor.defaultFormatter" = "ms-python.python";
          "[rust]"."editor.defaultFormatter" = "rust-lang.rust-analyzer";
          "[go]"."editor.defaultFormatter" = "golang.go";

          # Editor behavior
          "editor.tabSize" = 2;
          "editor.insertSpaces" = true;
          "editor.rulers" = [ 100 ];
          "editor.minimap.enabled" = false;
          "editor.bracketPairColorization.enabled" = true;
          "editor.guides.bracketPairs" = "active";
          "editor.stickyScroll.enabled" = true;
          "editor.linkedEditing" = true;

          # Files
          "files.trimTrailingWhitespace" = true;
          "files.insertFinalNewline" = true;
          "files.trimFinalNewlines" = true;
          "files.autoSave" = "onFocusChange";

          # Telemetry off
          "telemetry.telemetryLevel" = "off";
          "redhat.telemetry.enabled" = false;

          # Git
          "git.autofetch" = true;
          "git.confirmSync" = false;
          "git.enableSmartCommit" = true;

          # Terminal
          "terminal.integrated.defaultProfile.linux" = "zsh";

          # Explorer
          "explorer.confirmDelete" = false;
          "explorer.confirmDragAndDrop" = false;

          # Nix IDE - point at nixd which is installed at the system level
          "nix.enableLanguageServer" = true;
          "nix.serverPath" = "nixd";
        };
      };
    };
  };
}
