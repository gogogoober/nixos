# Common home config: git, gh, CLI tools, XDG
{ config, lib, pkgs, ... }:

with lib;
let cfg = config.modules.common;
in {
  options.modules.common = {
    enable = mkEnableOption "common home configuration" // { default = true; };
  };

  config = mkIf cfg.enable {
    home.stateVersion = "25.05";

    programs.git = {
      enable = true;
      userName = "Hugo";
      userEmail = "juicebox.salinas@gmail.com";
    };

    programs.gh.enable = true;

    programs.zoxide = {
      enable = true;
      enableZshIntegration = true;
    };

    programs.fzf = {
      enable = true;
      enableZshIntegration = true;
    };

    programs.bat.enable = true;
    programs.eza.enable = true;

    programs.home-manager.enable = true;
  };
}
