{
  config,
  lib,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.terminal;
in
{
  options.modules.terminal = {
    enable = mkEnableOption "terminal configuration";
  };

  config = mkIf cfg.enable {
    programs.ghostty = {
      enable = true;
      enableZshIntegration = true;
      settings = {
        theme = "GitHub Dark Default";
        font-family = "JetBrainsMono Nerd Font";
        font-size = 12;
        bell-features = "no-audio,no-system";
      };
    };
  };
}
