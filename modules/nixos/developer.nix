{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.developer;
in
{
  options.modules.developer = {
    enable = mkEnableOption "system-level developer toolchain";
  };

  config = mkIf cfg.enable {
    virtualisation.docker.enable = true;
    users.users.${config.modules.user.name}.extraGroups = [ "docker" ];

    environment.systemPackages = with pkgs; [
      docker-compose # Docker orchestration CLI
      gcc # C/C++ compiler - nicetohave dependency
      gnumake # Build tool - nicetohave dependency
      go # Go toolchain and runtime
      python3 # System Python runtime
      nodejs_24 # System Node runtime, current LTS, includes npm
      pnpm # Fast Node package manager
    ];
  };
}
