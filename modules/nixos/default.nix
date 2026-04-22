# Barrel file - imports all NixOS modules
{
  imports = [
    ./common.nix
    ./desktop.nix
    ./hyprland.nix
    ./gnome.nix
    ./touchscreen.nix
    ./developer.nix
    ./gaming.nix
  ];
}
