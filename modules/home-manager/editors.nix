# Editor configuration: vscode with language extensions
{ config, lib, pkgs, ... }:

with lib;
let cfg = config.modules.editors;
in {
  options.modules.editors = {
    enable = mkEnableOption "editor configuration";
  };

  config = mkIf cfg.enable {
    programs.vscode = {
      enable = true;
      extensions = with pkgs.vscode-extensions; [
        # General
        vscodevim.vim
        esbenp.prettier-vscode
        dbaeumer.vscode-eslint
        eamodio.gitlens
        mkhl.direnv

        # Go
        golang.go

        # Rust
        rust-lang.rust-analyzer

        # TypeScript / JavaScript
        bradlc.vscode-tailwindcss

        # Nix
        jnoortheen.nix-ide
      ];
      userSettings = {
        "editor.fontFamily" = "'JetBrains Mono', 'Fira Code', monospace";
        "editor.fontLigatures" = true;
        "editor.fontSize" = 14;
        "editor.formatOnSave" = true;
        "editor.minimap.enabled" = false;
        "editor.tabSize" = 2;
        "terminal.integrated.fontFamily" = "'JetBrainsMono Nerd Font'";
        "nix.enableLanguageServer" = true;
        "nix.serverPath" = "nil";
        "nix.serverSettings"."nil"."formatting"."command" = [ "nixpkgs-fmt" ];
      };
    };

    programs.git = {
      enable = true;
      userName = "Hugo";
      extraConfig = {
        init.defaultBranch = "main";
        push.autoSetupRemote = true;
        pull.rebase = true;
      };
    };
  };
}
