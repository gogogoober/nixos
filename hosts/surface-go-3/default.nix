# Surface Go - host configuration
{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    ./hardware.nix
    ../../modules/nixos
  ];

  networking.hostName = "surface-go-3";
  system.stateVersion = "25.05";

  # Module enable flags
  modules = {
    common.enable = true;
    desktop.enable = true;
    gnome.enable = false;
    hyprland.enable = true;
    touchscreen.enable = true;
    developer.enable = true;
    gaming.enable = false;
  };

  # User account
  users.users.hugo = {
    isNormalUser = true;
    description = "Hugo";
    extraGroups = [ "wheel" "networkmanager" "video" "input" ];
    shell = pkgs.zsh;
  };

  # Hardware quirks specific to this machine go here
}
