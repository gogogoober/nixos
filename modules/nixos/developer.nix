# System-level dev toolchain: docker daemon and language runtimes that any user
# or service on the host may need. Personal editor tooling lives in the
# home-manager devtools module instead.
# Docker group membership is a user mutation - set in the host file, not here.
{ config, lib, pkgs, ... }:

with lib;
let cfg = config.modules.developer;
in {
  options.modules.developer = {
    enable = mkEnableOption "system-level developer toolchain";
  };

  config = mkIf cfg.enable {
    virtualisation.docker.enable = true;

    environment.systemPackages = with pkgs; [
      docker-compose  # Docker orchestration CLI
      gcc             # C/C++ compiler
      gnumake         # Build tool
      python3         # System Python runtime
      nodejs_20       # System Node runtime
      pnpm            # Fast Node package manager
    ];
  };
}
