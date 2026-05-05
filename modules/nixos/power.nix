{
  config,
  lib,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.power;
in
{
  options.modules.power = {
    enable = mkEnableOption "auto sleep and hibernate timeouts" // {
      default = true;
    };
  };

  config = mkIf cfg.enable {
    systemd.sleep.settings.Sleep = {
      AllowHibernation = false;
      AllowHybridSleep = false;
      AllowSuspendThenHibernate = false;
    };
  };
}
