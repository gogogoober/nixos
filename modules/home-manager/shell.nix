# Shell configuration: zsh, starship prompt, direnv, aliases
{ config, lib, pkgs, ... }:

with lib;
let cfg = config.modules.shell;
in {
  options.modules.shell = {
    enable = mkEnableOption "shell configuration";
  };

  config = mkIf cfg.enable {
    programs.zsh = {
      enable = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
      history = {
        size = 10000;
        ignoreAllDups = true;
      };
      shellAliases = {
        ls = "eza --icons";
        ll = "eza -la --icons";
        lt = "eza --tree --icons";
        cat = "bat";
        g = "git";
        gs = "git status";
        gd = "git diff";
        gc = "git commit";
        gp = "git push";
        gl = "git log --oneline --graph";
        dc = "docker compose";
        nr = "sudo nixos-rebuild switch --flake .";
        nf = "nix flake update";
      };
    };

    programs.starship = {
      enable = true;
      settings = {
        add_newline = true;
        character = {
          success_symbol = "[➜](bold green)";
          error_symbol = "[✗](bold red)";
        };
        nix_shell.symbol = " ";
        golang.symbol = " ";
        rust.symbol = " ";
        nodejs.symbol = " ";
      };
    };

    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    programs.fzf = {
      enable = true;
      enableZshIntegration = true;
    };

    programs.zoxide = {
      enable = true;
      enableZshIntegration = true;
    };
  };
}
