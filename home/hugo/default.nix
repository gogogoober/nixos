# Home-manager entry point for user hugo
{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    ../../modules/home-manager
  ];

  home.username = "hugo";
  home.homeDirectory = "/home/hugo";

  # Module enable flags
  modules = {
    common.enable = true;
    shell.enable = true;
    editors.enable = true;
    terminal.enable = true;
    desktop.enable = true;
  };
}
