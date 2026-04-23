# Editor configuration: neovim (LazyVim), vscode
# LazyVim is bootstrapped manually by cloning the starter into ~/.config/nvim on first run.
# Declarative LazyVim management is deferred.
{ config, lib, pkgs, ... }:

with lib;
let cfg = config.modules.editors;
in {
  options.modules.editors = {
    enable = mkEnableOption "editor configuration";
  };

  config = mkIf cfg.enable {
    programs.neovim = {
      enable = true;
      defaultEditor = true;
    };

    programs.vscode = {
      enable = true;
      package = pkgs.vscode-fhs;
    };
  };
}
