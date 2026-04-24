{
  config,
  lib,
  pkgs,
  ...
}:

with lib;
let
  cfg = config.modules.shell;

  # Pin preset to match installed starship; newer presets carry modules
  # the older binary rejects with "Unknown key" warnings at shell start.
  starshipPreset = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/starship/starship/v1.24.2/docs/public/presets/toml/nerd-font-symbols.toml";
    sha256 = "0f0pykrldyr5cxva278ahjs0xnqbm9gig7w8g850rswmiscc65fg";
  };

  starshipSettings =
    let
      preset = fromTOML (builtins.readFile starshipPreset);
    in
    preset
    // {
      directory = preset.directory // {
        truncation_length = 5;
        truncate_to_repo = false;
      };
      status = preset.status // {
        disabled = false;
      };
    };
in
{
  options.modules.shell = {
    enable = mkEnableOption "shell configuration";
  };

  config = mkIf cfg.enable {
    programs.zsh = {
      enable = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
      shellAliases = {
        ll = "eza -la";
        tree = "eza --tree";
        cat = "bat";
        cd = "z";
      };
    };

    programs.starship = {
      enable = true;
      enableTransience = true;
      settings = starshipSettings;
    };
  };
}
