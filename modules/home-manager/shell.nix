# Shell configuration: zsh, starship prompt, aliases
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
        ll = "eza -la";
        tree = "eza --tree";
        cat = "bat";
        cd = "z";
      };
    };

    programs.starship = {
      enable = true;
    };
  };
}
