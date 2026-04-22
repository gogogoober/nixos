# Shell configuration: zsh, aliases, prompt, shell plugins
{ config, lib, pkgs, ... }:

with lib;
let cfg = config.modules.shell;
in {
  options.modules.shell = {
    enable = mkEnableOption "shell configuration";
  };

  config = mkIf cfg.enable {
    # Shell config goes here
  };
}
