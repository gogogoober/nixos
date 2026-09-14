{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  inherit (lib) mkEnableOption mkForce mkIf;
  cfg = config.modules.common;

  generationsKept = 5; # Boot menu entries, and what the weekly gc spares
  scratchpadAge = "2d"; # Idle time before systemd-tmpfiles takes an agent scratchpad
in
{
  options.modules.common = {
    enable = mkEnableOption "common system configuration" // {
      default = true;
    };
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
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      trusted-users = [
        "root"
        "@wheel"
      ];
      max-jobs = 1; # One build at a time, still uses every core
    };

    # Let interactive work preempt Nix builds and the weekly auto-upgrade
    nix.daemonCPUSchedPolicy = "idle";
    nix.daemonIOSchedClass = "idle";
    nix.daemonIOSchedPriority = 7;

    # Weekly store dedup instead of after every build
    nix.optimise = {
      automatic = true;
      dates = [ "weekly" ];
    };

    # Upstream skips this on battery, which on a tablet means never
    systemd.services.nix-optimise = {
      unitConfig.ConditionACPower = mkForce null;
      serviceConfig = {
        CPUSchedulingPolicy = "idle"; # Yield to anything interactive
        IOSchedulingClass = "idle";
      };
    };

    boot.loader.systemd-boot.configurationLimit = generationsKept;

    nix.gc = {
      automatic = true;
      dates = "weekly";
    };

    # systemd's own /tmp rule is 10 days, too long for multi-gigabyte scratchpads
    systemd.tmpfiles.rules = [ "e /tmp/claude-*/* - - - ${scratchpadAge}" ];

    # nix-collect-garbage has no keep-newest-N flag, so prune the profile first
    systemd.services.nix-gc.serviceConfig.ExecStartPre =
      "${config.nix.package}/bin/nix-env --delete-generations +${toString generationsKept} -p /nix/var/nix/profiles/system";

    system.autoUpgrade = {
      enable = true;
      flake = inputs.self.outPath;
      flags = [
        "--recreate-lock-file" # Deprecated, but the only in-place update for a store-path flake
        "-L"
      ];
      dates = "Mon 09:00";
      randomizedDelaySec = "45min";
      persistent = true;
    };

    # Skipped weeks wait for the next Monday
    systemd.services.nixos-upgrade.unitConfig.ConditionACPower = true;

    nixpkgs.config.allowUnfree = true;
    nixpkgs.overlays = import ../../overlays { inherit inputs; };

    networking.networkmanager.enable = true;
    users.users.${config.modules.user.name}.extraGroups = [ "networkmanager" ];

    # Silence PC speaker beeps
    boot.blacklistedKernelModules = [
      "pcspkr"
      "snd_pcsp"
    ];

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
      git # Version control
      vim # Fallback editor
      wget # HTTP downloader
      curl # HTTP client
      htop # Process viewer
      tree # Directory tree printer
      unzip # Zip archive extractor
      file # File type detector
      ripgrep # Fast recursive grep
      fd # Friendlier find
      bat # Cat with syntax highlighting
      eza # Modern ls
      fzf # Fuzzy finder
      zoxide # Smarter cd
      jq # JSON processor
      hunspell # Spell checker, picked up by GTK, Qt, Chromium apps - nicetohave dependency
      hunspellDicts.en_US-large # US English dictionary for hunspell - nicetohave dependency
    ];
  };
}
