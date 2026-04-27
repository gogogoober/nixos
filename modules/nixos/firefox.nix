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
    enable = mkEnableOption "Firefox with Catppuccin Mocha Mauve preinstalled" // {
      default = true;
    };
  };

  config = mkIf cfg.enable {
    programs.firefox = {
      enable = true;

      # Force-install the AMO theme; activation lives in the home-manager profile.
      policies.ExtensionSettings.${catppuccinMochaMauveId} = {
        installation_mode = "force_installed";
        install_url = "https://addons.mozilla.org/firefox/downloads/latest/catppuccin-mocha-mauve/latest.xpi";
      };
    };
  };
}
