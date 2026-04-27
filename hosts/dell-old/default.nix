{ pkgs, ... }:

{
  imports = [
    ./hardware.nix
    ../../modules/nixos
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "dell-old";
  system.stateVersion = "25.05";

  # Both DEs can be enabled; GDM offers both at login
  modules = {
    common.enable = true;
    desktop.enable = true;
    gnome.enable = false;
    hyprland.enable = true;
    touchscreen.enable = false;
    developer.enable = true;
    tts.enable = true;
    tts.devMode = true;
    stt.enable = true;
    gaming.enable = true;

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

  hardware.firmware = [ pkgs.linux-firmware ];
  services.fprintd.enable = false;

  # macOS muscle memory
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
