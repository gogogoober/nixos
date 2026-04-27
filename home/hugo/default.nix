{ osConfig, ... }:

let
  username = osConfig.modules.user.name;
in
{
  imports = [
    ../../modules/home-manager
  ];

  home.username = username;
  home.homeDirectory = "/home/${username}";

  modules = {
    common.enable = true;
    shell.enable = true;
    vscode.enable = true;
    devtools.enable = true;
    neovim.enable = true;
    terminal.enable = true;
    firefox.enable = true;
    claude.enable = true;
  };
}
