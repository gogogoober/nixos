# Common home config: base packages, XDG dirs
{ config, lib, pkgs, ... }:

with lib;
let cfg = config.modules.common;
in {
  options.modules.common = {
    enable = mkEnableOption "common home configuration" // { default = true; };
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      ripgrep
      fd
      bat
      eza
      fzf
      tree
      tldr
      du-dust
    ];

    xdg.enable = true;

    programs.home-manager.enable = true;
  };
}
