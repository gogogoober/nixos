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
    enable = mkEnableOption "sleep, thermal, and swap behaviour" // {
      default = true;
    };
  };

  config = mkIf cfg.enable {
    systemd.sleep.settings.Sleep = {
      AllowHibernation = false;
      AllowHybridSleep = false;
      AllowSuspendThenHibernate = false;
    };

    # Compressed RAM swap, faster overflow than the disk partition
    zramSwap = {
      enable = true;
      algorithm = "zstd";
      memoryPercent = 50;
    };

    services.thermald.enable = true;
  };
}
