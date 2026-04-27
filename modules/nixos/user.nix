{
  config,
  lib,
  pkgs,
  ...
}:

with lib;
let
  cfg = config.modules.user;
in
{
  options.modules.user = {
    name = mkOption {
      type = types.str;
      description = "Primary user account name";
    };

    description = mkOption {
      type = types.str;
      default = "";
      description = "GECOS description for the user";
    };

    extraGroups = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Additional groups beyond the user's primary group";
    };

    homeConfig = mkOption {
      type = types.path;
      description = "Path to the user's home-manager config (directory with default.nix or single file)";
    };
  };

  config = {
    users.users.${cfg.name} = {
      isNormalUser = true;
      inherit (cfg) description extraGroups;
      shell = pkgs.zsh;
    };

    home-manager.users.${cfg.name} = import cfg.homeConfig;
  };
}
