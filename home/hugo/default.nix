{ ... }:

{
  imports = [
    ../../modules/home-manager
  ];

  home.username = "hugo";
  home.homeDirectory = "/home/hugo";

  modules = {
    common.enable = true;
    shell.enable = true;
    vscode.enable = true;
    devtools.enable = true;
    lazy-nvf.enable = true;
    terminal.enable = true;
    desktop.enable = true;
    claude.enable = true;
  };
}
