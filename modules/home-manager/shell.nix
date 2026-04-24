# Shell configuration: zsh, starship prompt, aliases
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;
let
  cfg = config.modules.shell;
in
{
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
        ll = "eza -la";
        tree = "eza --tree";
        cat = "bat";
        cd = "z";
      };
      initContent = ''
        unsetopt BEEP
      '';
    };

    programs.starship = {
      enable = true;
      settings = {
        "$schema" = "https://starship.rs/config-schema.json";

        format = "$directory$git_branch$git_status\n$character";

        directory = {
          truncation_length = 4;
          truncate_to_repo = false;
          truncation_symbol = "…/";
          style = "blue";
          format = "[$path]($style) ";
          substitutions = {
            "Documents" = "󰈙 ";
            "Downloads" = " ";
            "Music" = " ";
            "Pictures" = " ";
          };
        };

        git_branch = {
          symbol = " ";
          style = "purple";
          format = "[$symbol$branch]($style) ";
        };

        git_status = {
          style = "yellow";
          format = "([$all_status$ahead_behind]($style) )";
          modified = " ";
          staged = " ";
          untracked = " ";
          deleted = " ";
          renamed = " ";
          stashed = " ";
          conflicted = " ";
          ahead = " ";
          behind = " ";
          diverged = " ";
        };
      };
    };
  };
}
