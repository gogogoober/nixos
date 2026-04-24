{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    ./hardware.nix
    ../../modules/nixos
  ];

  networking.hostName = "surface-go-3";
  system.stateVersion = "25.05";

  modules = {
    common.enable = true;
    desktop.enable = true;
    gnome.enable = true;
    hyprland.enable = false;
    touchscreen.enable = true;
    developer.enable = true;
    tts.enable = true;
    stt.enable = true;
    gaming.enable = false;
  };

  users.users.hugo = {
    isNormalUser = true;
    description = "Hugo";
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "input"
      "docker"
    ];
    shell = pkgs.zsh;
  };
}
