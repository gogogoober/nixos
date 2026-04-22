# Dell Old - host configuration
{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    ./hardware.nix
    ../../modules/nixos
  ];

  networking.hostName = "dell-old";
  system.stateVersion = "25.05";

  # Module enable flags
  modules = {
    common.enable = true;
    desktop.enable = true;
    gnome.enable = true;
    hyprland.enable = false;
    touchscreen.enable = false;
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

  # Hardware quirks specific to this machine
  hardware.firmware = [ pkgs.linux-firmware ];
  services.fprintd.enable = false;
}
