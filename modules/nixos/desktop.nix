# Shared graphical stack: pipewire, fonts, xdg portals, printing, bluetooth
{ config, lib, pkgs, ... }:

with lib;
let cfg = config.modules.desktop;
in {
  options.modules.desktop = {
    enable = mkEnableOption "shared desktop/graphical stack";
  };

  config = mkIf cfg.enable {
    # Display manager (GDM) — always on, regardless of which DE is active.
    # GDM offers whichever sessions are installed (GNOME, Hyprland, etc.),
    # so flipping modules.gnome.enable / modules.hyprland.enable just changes
    # which session is available at login.
    services.xserver.enable = true;
    services.displayManager.gdm.enable = true;

    # Audio - full pipewire stack
    services.pulseaudio.enable = false;
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
    };

    # XDG portals
    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    };

    # Fonts
    fonts.packages = with pkgs; [
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      liberation_ttf
      jetbrains-mono
      nerd-fonts.fira-code
      nerd-fonts.jetbrains-mono
    ];

    # Printing + network scanner discovery
    services.printing.enable = true;
    services.avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };

    # Bluetooth
    hardware.bluetooth.enable = true;
    hardware.bluetooth.powerOnBoot = true;
    services.blueman.enable = true;

    # GUI utilities
    environment.systemPackages = with pkgs; [
      firefox
      pavucontrol
      networkmanagerapplet
      brightnessctl
      playerctl
      # wl-copy / wl-paste CLI — used by TTS (speak-selection) and any
      # clipboard scripting; not shipped by GNOME or Hyprland by default.
      wl-clipboard
      # Synthesizes keystrokes on Wayland; required by STT to type
      # recognized text into the focused window on any Wayland DE.
      wtype
    ];
  };
}
