# Editor configuration: neovim, vscode, editor plugins
{ config, lib, pkgs, ... }:

with lib;
let cfg = config.modules.editors;
in {
  options.modules.editors = {
    enable = mkEnableOption "editor configuration";
  };

  config = mkIf cfg.enable {
    # Editors config goes here
  };
}
