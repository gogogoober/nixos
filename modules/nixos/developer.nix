# Developer tools: docker, language runtimes, dev utilities
{ config, lib, pkgs, ... }:

with lib;
let cfg = config.modules.developer;
in {
  options.modules.developer = {
    enable = mkEnableOption "developer tools and utilities";
  };

  config = mkIf cfg.enable {
    # Docker
    virtualisation.docker.enable = true;
    users.extraGroups.docker.members = [ "hugo" ];

    # Nix tooling
    programs.direnv.enable = true;

    environment.systemPackages = with pkgs; [
      # Version control
      git
      gh

      # Language runtimes & toolchains
      go
      rustup
      nodejs_22
      corepack_22   # enables pnpm/yarn without global install
      typescript

      # Build tools
      gcc
      gnumake
      pkg-config
      openssl

      # Dev utilities
      claude-code
      jq
      yq-go
      httpie
      docker-compose
    ];
  };
}
