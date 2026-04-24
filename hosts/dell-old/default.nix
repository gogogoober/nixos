# Dell Old - host configuration
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

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "dell-old";
  system.stateVersion = "25.05";

  # Module enable flags.
  # DE toggle: flip these two to swap between GNOME and Hyprland. Both can
  # be true simultaneously (GDM will offer both sessions at login).
  modules = {
    common.enable = true;
    desktop.enable = true;
    gnome.enable = false;
    hyprland.enable = true;
    touchscreen.enable = false;
    developer.enable = true;
    tts.enable = true;
    stt.enable = true;
    gaming.enable = true;
  };

  # Mirror the NixOS Hyprland flag into home-manager so the user's Hyprland
  # config (keybinds, monitor, autostart) is generated iff the session is.
  home-manager.users.hugo.modules.hyprland.enable = config.modules.hyprland.enable;

  # User account
  users.users.hugo = {
    isNormalUser = true;
    description = "Hugo";
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "input"
      "docker"
      "ydotool"
    ];
    shell = pkgs.zsh;
  };

  # Hardware quirks specific to this machine
  hardware.firmware = [ pkgs.linux-firmware ];
  services.fprintd.enable = false;

  # Swap Ctrl and Alt to match macOS muscle memory
  services.xserver.xkb.options = "ctrl:swap_lalt_lctl";
  services.keyd = {
    enable = true;
    keyboards.default = {
      ids = [ "*" ];
      settings.main = {
        leftalt = "leftcontrol";
        leftcontrol = "leftalt";
      };
    };
  };
}
