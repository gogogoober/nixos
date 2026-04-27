{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.desktop;
in
{
  options.modules.desktop = {
    enable = mkEnableOption "shared desktop/graphical stack";
  };

  config = mkIf cfg.enable {
    services.xserver.enable = true;
    services.displayManager.gdm.enable = true;

    services.pulseaudio.enable = false;
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
    };

    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    };

    fonts.packages = with pkgs; [
      noto-fonts # Broad Unicode coverage
      noto-fonts-cjk-sans # CJK glyphs
      noto-fonts-color-emoji # Color emoji
      liberation_ttf # Metric-compatible MS fonts
      jetbrains-mono # Monospace
      nerd-fonts.fira-code # Icon-patched Fira Code
      nerd-fonts.jetbrains-mono # Icon-patched JetBrains Mono
    ];

    services.printing.enable = true;
    services.avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };

    hardware.bluetooth.enable = true;
    hardware.bluetooth.powerOnBoot = true;
    services.blueman.enable = true;

    environment.systemPackages = with pkgs; [
      firefox # Web browser
      pavucontrol # PulseAudio volume GUI
      networkmanagerapplet # NetworkManager tray applet
      brightnessctl # Backlight control CLI
      playerctl # MPRIS media keys CLI
      wl-clipboard # Wayland clipboard CLI
      wtype # Synthesize keystrokes on Wayland
    ];
  };
}
