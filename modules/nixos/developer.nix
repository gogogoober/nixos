# Developer tools: docker, language runtimes, dev utilities
# Docker group membership is a user mutation - set in the host file, not here.
{ config, lib, pkgs, ... }:

with lib;
let cfg = config.modules.developer;
in {
  options.modules.developer = {
    enable = mkEnableOption "developer tools and utilities";
  };

  config = mkIf cfg.enable {
    virtualisation.docker.enable = true;

    environment.systemPackages = with pkgs; [
      docker-compose
      lazygit
      gh
      gcc
      gnumake
      python3
      nodejs_20
      pnpm
      claude-code
      vscode
    ];
  };
}
