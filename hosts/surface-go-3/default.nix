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
    intelPowerLimit = {
      enable = true;
      profiles = {
        power-saver = {
          sustainedWatts = 5;
          burstWatts = 10;
        };
        balanced = {
          sustainedWatts = 5;
          burstWatts = 15;
        };
        performance = {
          sustainedWatts = 9;
          burstWatts = 20;
        };
      };
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
