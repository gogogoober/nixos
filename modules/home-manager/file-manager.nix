{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.file-manager;
in
{
  options.modules.file-manager = {
    enable = mkEnableOption "TUI file manager (superfile)";
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.superfile ];
  };
}
