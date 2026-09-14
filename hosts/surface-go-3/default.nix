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
    gnome = {
      enable = true;
      # 48 Hz is offered alongside 60 and costs less on a panel this size
      display = {
        connector = "eDP-1";
        vendor = "BOE";
        product = "0x088b";
        width = 1920;
        height = 1280;
        rate = "47.998";
        scale = 2;
      };
    };
    hyprland.enable = false;
    touchscreen.enable = true;
    developer.enable = true;
    tts.enable = true;
    stt = {
      enable = true;
      engine = "whisper-small"; # encoder runs on the UHD 615, so small costs ~11 s instead of ~56 s
      threads = 2;
    };
    gaming.enable = true;
    # The EC latches into a no-adapter state; only a firmware reset clears it
    chargerWatch = {
      enable = true;
      adapter = "ACAD";
      battery = "BAT1";
      recovery = "Hold volume-up + power for 20 seconds, release, then power on.";
    };

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

    profileBrightness = {
      enable = true;
      greeterPercent = 30;
      loginProfile = "power-saver";
      profiles = {
        power-saver = 20;
        balanced = 50;
        performance = 60;
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
