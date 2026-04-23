# Shared graphical stack: pipewire, fonts, xdg portals, bluetooth, printing
{ config, lib, pkgs, ... }:

with lib;
let cfg = config.modules.desktop;
in {
  options.modules.desktop = {
    enable = mkEnableOption "shared desktop/graphical stack";
  };

  config = mkIf cfg.enable {
    # Audio via pipewire
    services.pulseaudio.enable = false;
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };

    # Bluetooth
    hardware.bluetooth.enable = true;
    hardware.bluetooth.powerOnBoot = true;

    # Printing
    services.printing.enable = true;

    # Fonts
    fonts.packages = with pkgs; [
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-emoji
      fira-code
      fira-code-symbols
      jetbrains-mono
      (nerdfonts.override { fonts = [ "FiraCode" "JetBrainsMono" ]; })
    ];

    # XDG portals (base - compositors add their own)
    xdg.portal.enable = true;

    # X11 keymap
    services.xserver.xkb = {
      layout = "us";
      variant = "";
    };
  };
}
