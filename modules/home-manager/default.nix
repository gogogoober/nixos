# Barrel file - imports all home-manager modules
{
  imports = [
    ./common.nix
    ./shell.nix
    ./editors.nix
    ./devtools.nix
    ./lazy-nvf.nix
    ./terminal.nix
    ./desktop.nix
    ./hyprland
    ./claude.nix
  ];
}
