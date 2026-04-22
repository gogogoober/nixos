# Barrel file - imports all home-manager modules
{
  imports = [
    ./common.nix
    ./shell.nix
    ./editors.nix
    ./terminal.nix
    ./desktop.nix
  ];
}
