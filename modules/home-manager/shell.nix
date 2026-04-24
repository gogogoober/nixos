{
  config,
  lib,
  pkgs,
  ...
}:

with lib;
let
  cfg = config.modules.shell;

  starshipPreset = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/starship/starship/v1.25.0/docs/public/presets/toml/nerd-font-symbols.toml";
    sha256 = "1v4cda5zf5a9wirgxc1in6c40wrsa7pbjphb9ihkrgkwgp8jhj5q";
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
      settings = fromTOML (builtins.readFile starshipPreset);
    };
  };
}
