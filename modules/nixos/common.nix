# Common system configuration: locale, timezone, nix settings, networking, SSH, firewall, base CLI
{ config, lib, pkgs, ... }:

with lib;
let cfg = config.modules.common;
in {
  options.modules.common = {
    enable = mkEnableOption "common system configuration" // { default = true; };
  };

  config = mkIf cfg.enable {
    time.timeZone = "America/Chicago";

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

    nix.settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
      trusted-users = [ "root" "@wheel" ];
    };

    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };

    nixpkgs.config.allowUnfree = true;

    networking.networkmanager.enable = true;

    # Kill all system beeps — PC speaker kernel modules
    boot.blacklistedKernelModules = [ "pcspkr" "snd_pcsp" ];

    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "no";
      };
    };

    networking.firewall.enable = true;

    programs.zsh.enable = true;

    programs.nix-ld = {
      enable = true;
      libraries = with pkgs; [
        stdenv.cc.cc.lib
        zlib
        openssl
      ];
    };

    environment.systemPackages = with pkgs; [
      git
      vim
      wget
      curl
      htop
      tree
      unzip
      file
      ripgrep
      fd
      bat
      eza
      fzf
      zoxide
      jq

      # Spell check dictionaries picked up by GTK, Qt, and Chromium-based apps
      hunspell
      hunspellDicts.en_US-large
    ];
  };
}
