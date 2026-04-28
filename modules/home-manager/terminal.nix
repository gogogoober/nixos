{
  config,
  lib,
  pkgs,
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

    # Provide a com.mitchellh.ghostty icon so the launcher uses Reversal-dark's generic terminal glyph
    home.file.".local/share/icons/hicolor/scalable/apps/com.mitchellh.ghostty.svg".source =
      "${pkgs.reversal-icon-theme}/share/icons/Reversal-dark/apps/scalable/terminal.svg";
  };
}
