{
  config,
  lib,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.firefox;

  catppuccinMochaMauveId = "{d090b7ee-a385-4d54-b9a4-f7164d17756d}";
in
{
  options.modules.firefox = {
    enable = mkEnableOption "Firefox profile with Catppuccin Mocha Mauve as the active theme" // {
      default = true;
    };
  };

  config = mkIf cfg.enable {
    programs.firefox = {
      enable = true;
      package = null; # System Firefox is wrapped with policies; HM only manages profiles.

      profiles.default = {
        isDefault = true;
        settings = {
          "extensions.activeThemeID" = catppuccinMochaMauveId;
        };
      };
    };
  };
}
