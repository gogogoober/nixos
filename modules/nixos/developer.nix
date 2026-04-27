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
      gcc # C/C++ compiler
      gnumake # Build tool
      python3 # System Python runtime
      nodejs_20 # System Node runtime
      pnpm # Fast Node package manager
    ];
  };
}
