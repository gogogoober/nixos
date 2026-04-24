# Home-manager entry point for user hugo
{ ... }:

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
    devtools.enable = true;
    lazy-nvf.enable = true;
    terminal.enable = true;
    desktop.enable = true;
    claude.enable = true;
  };
}
