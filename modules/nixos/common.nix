# Common system configuration: locale, timezone, nix settings, bootloader, networking, base packages
{ config, lib, pkgs, ... }:

with lib;
let cfg = config.modules.common;
in {
  options.modules.common = {
    enable = mkEnableOption "common system configuration" // { default = true; };
  };

  config = mkIf cfg.enable {
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;

    networking.networkmanager.enable = true;

    time.timeZone = "America/New_York";

    i18n.defaultLocale = "en_US.UTF-8";
    i18n.extraLocaleSettings = {
      LC_ADDRESS = "en_US.UTF-8";
      LC_IDENTIFICATION = "en_US.UTF-8";
      LC_MEASUREMENT = "en_US.UTF-8";
      LC_MONETARY = "en_US.UTF-8";
      LC_NAME = "en_US.UTF-8";
      LC_NUMERIC = "en_US.UTF-8";
      LC_PAPER = "en_US.UTF-8";
      LC_TELEPHONE = "en_US.UTF-8";
      LC_TIME = "en_US.UTF-8";
    };

    nix.settings.experimental-features = [ "nix-command" "flakes" ];
    nixpkgs.config.allowUnfree = true;

    programs.zsh.enable = true;

    environment.systemPackages = with pkgs; [
      vim
      git
      curl
      wget
      htop
      unzip
    ];
  };
}
