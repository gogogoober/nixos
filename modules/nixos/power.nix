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
    # Sleep fires at 7 min idle, hibernate at 15 min total — so 8 min in suspend
    systemd.sleep.settings.Sleep.HibernateDelaySec = "8m";
  };
}
