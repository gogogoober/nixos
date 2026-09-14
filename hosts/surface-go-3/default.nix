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
    gaming.enable = true;
    chargerWatch.enable = true;

    # 5W part the firmware runs at 15W sustained, so it boosts into a throttle
    powerLimit = {
      enable = true;
      sustainedWatts = 7;
      burstWatts = 15;
    };

    user = {
      name = "hugo";
      description = "Hugo";
      extraGroups = [
        "wheel"
        "video"
        "input"
      ];
      homeConfig = ../../home/hugo;
    };
  };
}
