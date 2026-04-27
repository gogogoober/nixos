{ ... }:

{
  imports = [
    ./hardware.nix
    ../../modules/nixos
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

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

    user = {
      name = "hugo";
      description = "Hugo";
      extraGroups = [
        "wheel"
        "networkmanager"
        "video"
        "input"
        "docker"
      ];
      homeConfig = ../../home/hugo;
    };
  };
}
