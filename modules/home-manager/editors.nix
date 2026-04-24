{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.modules.editors;

  # Wrap seed script with the seed JSON path baked in
  vscodeSettingsSeed = pkgs.writeShellApplication {
    name = "vscode-settings-seed";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      export VSCODE_SEED=${./../../assets/vscode/settings.json}
      # shellcheck source=/dev/null
      source ${./scripts/vscode-settings-seed.sh}
    '';
  };
in
{
  options.modules.editors = {
    enable = mkEnableOption "baseline editors (vim and VSCode)" // {
      default = true;
    };

    vscode.enable = mkOption {
      type = types.bool;
      default = true;
      description = "Install and configure VSCode with sensible defaults.";
    };
  };

  config = mkIf cfg.enable {
    programs.vim = {
      enable = true;
      defaultEditor = false; # nvf's neovim wins
      settings = {
        number = true;
        relativenumber = true;
        tabstop = 2;
        shiftwidth = 2;
        expandtab = true;
        ignorecase = true;
        smartcase = true;
      };
      extraConfig = ''
        syntax on
        set mouse=a
        set clipboard=unnamedplus
      '';
    };

    programs.vscode = mkIf cfg.vscode.enable {
      enable = true;
      package = pkgs.vscode-fhs; # FHS wrap for extensions with bundled binaries

      profiles.default = {
        extensions = with pkgs.vscode-extensions; [
          enkia.tokyo-night # Theme
          esbenp.prettier-vscode # Formatter
          tekumara.typos-vscode # Typo checker
          bradlc.vscode-tailwindcss # Tailwind IntelliSense
          ms-python.python # Python language support
          rust-lang.rust-analyzer # Rust language server
          golang.go # Go language support
          jnoortheen.nix-ide # Nix language support
          angular.ng-template # Angular template language
          eamodio.gitlens # Git blame and history
          usernamehw.errorlens # Inline diagnostics
          christian-kohler.path-intellisense # Path autocomplete
          editorconfig.editorconfig # .editorconfig support
        ];
      };
    };

    home.packages = lib.optionals cfg.vscode.enable [ vscodeSettingsSeed ];

    # settings.json stays user-writable; seed copies onto it each rebuild
    home.activation = lib.optionalAttrs cfg.vscode.enable {
      seedVSCodeSettings = hm.dag.entryAfter [ "writeBoundary" ] ''
        $DRY_RUN_CMD ${vscodeSettingsSeed}/bin/vscode-settings-seed
      '';
    };
  };
}
