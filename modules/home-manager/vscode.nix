{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.modules.vscode;
in
{
  options.modules.vscode = {
    enable = mkEnableOption "VSCode with sensible defaults" // {
      default = true;
    };
  };

  config = mkIf cfg.enable {
    programs.vscode = {
      enable = true;
      package = pkgs.vscode-fhs; # FHS wrap for extensions with bundled binaries

      profiles.default = {
        extensions = with pkgs.vscode-extensions; [
          github.github-vscode-theme # GitHub theme
          esbenp.prettier-vscode # Formatter
          tekumara.typos-vscode # Typo checker
          bradlc.vscode-tailwindcss # Tailwind IntelliSense
          ms-python.python # Python language support
          rust-lang.rust-analyzer # Rust language server
          golang.go # Go language support
          jnoortheen.nix-ide # Nix language support
          angular.ng-template # Angular template language
          usernamehw.errorlens # Inline diagnostics
          christian-kohler.path-intellisense # Path autocomplete
          editorconfig.editorconfig # .editorconfig support
        ];

        userSettings = {
          "[css]" = {
            "editor.defaultFormatter" = "esbenp.prettier-vscode";
          };
          "[go]" = {
            "editor.defaultFormatter" = "golang.go";
          };
          "[html]" = {
            "editor.defaultFormatter" = "esbenp.prettier-vscode";
          };
          "[javascript]" = {
            "editor.defaultFormatter" = "esbenp.prettier-vscode";
          };
          "[javascriptreact]" = {
            "editor.defaultFormatter" = "esbenp.prettier-vscode";
          };
          "[json]" = {
            "editor.defaultFormatter" = "esbenp.prettier-vscode";
          };
          "[jsonc]" = {
            "editor.defaultFormatter" = "esbenp.prettier-vscode";
          };
          "[markdown]" = {
            "editor.defaultFormatter" = "esbenp.prettier-vscode";
          };
          "[nix]" = {
            "editor.defaultFormatter" = "jnoortheen.nix-ide";
          };
          "[python]" = {
            "editor.defaultFormatter" = "ms-python.python";
          };
          "[rust]" = {
            "editor.defaultFormatter" = "rust-lang.rust-analyzer";
          };
          "[scss]" = {
            "editor.defaultFormatter" = "esbenp.prettier-vscode";
          };
          "[typescript]" = {
            "editor.defaultFormatter" = "esbenp.prettier-vscode";
          };
          "[typescriptreact]" = {
            "editor.defaultFormatter" = "esbenp.prettier-vscode";
          };
          "[yaml]" = {
            "editor.defaultFormatter" = "esbenp.prettier-vscode";
          };
          "claudeCode.preferredLocation" = "panel";
          "editor.bracketPairColorization.enabled" = true;
          "editor.codeActionsOnSave" = {
            "source.fixAll" = "explicit";
            "source.organizeImports" = "explicit";
          };
          "editor.fontFamily" = "'JetBrainsMono Nerd Font', monospace";
          "editor.fontLigatures" = true;
          "editor.fontSize" = 13;
          "editor.formatOnPaste" = false;
          "editor.formatOnSave" = true;
          "editor.guides.bracketPairs" = "active";
          "editor.insertSpaces" = true;
          "editor.linkedEditing" = true;
          "editor.minimap.enabled" = false;
          "editor.rulers" = [ 100 ];
          "editor.stickyScroll.enabled" = true;
          "editor.tabSize" = 2;
          "explorer.confirmDelete" = false;
          "explorer.confirmDragAndDrop" = false;
          "files.autoSave" = "onFocusChange";
          "files.insertFinalNewline" = true;
          "files.trimFinalNewlines" = true;
          "files.trimTrailingWhitespace" = true;
          "git.autofetch" = true;
          "git.confirmSync" = false;
          "git.enableSmartCommit" = true;
          "nix.enableLanguageServer" = true;
          "nix.serverPath" = "nixd";
          "redhat.telemetry.enabled" = false;
          "telemetry.telemetryLevel" = "off";
          "terminal.integrated.defaultProfile.linux" = "zsh";
          "terminal.integrated.fontFamily" = "'JetBrainsMono Nerd Font'";
          "workbench.colorTheme" = "GitHub Dark Default";
          "workbench.editorAssociations" = {
            "*.md" = "vscode.markdown.preview.editor";
          };
        };
      };
    };
  };
}
