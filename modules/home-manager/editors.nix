{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.modules.editors;

  # Wraps the raw seed script with the Nix-store path to the seed JSON baked in.
  # The raw script is kept as a regular file (modules/home-manager/scripts/) so
  # it stays editable and runnable outside the Nix build; this wrapper is what
  # lands on PATH and is what the activation hook invokes.
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
    # Plain vim as universal fallback - light, always works, zero config surprises
    programs.vim = {
      enable = true;
      defaultEditor = false;   # nvf's neovim wins when both are installed
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

    # VSCode with FHS wrapping so extensions with bundled binaries work on NixOS
    programs.vscode = mkIf cfg.vscode.enable {
      enable = true;
      package = pkgs.vscode-fhs;

      profiles.default = {
        extensions = with pkgs.vscode-extensions; [
          # Theme
          enkia.tokyo-night

          # Formatters
          esbenp.prettier-vscode

          # Language support
          bradlc.vscode-tailwindcss
          ms-python.python
          rust-lang.rust-analyzer
          golang.go
          jnoortheen.nix-ide
          angular.ng-template

          # Git
          eamodio.gitlens

          # Quality of life
          usernamehw.errorlens
          christian-kohler.path-intellisense
          editorconfig.editorconfig
        ];

        # settings.json is NOT managed as a nix-store symlink here. Home Manager
        # would make it read-only, which breaks any extension that writes to it
        # (e.g. Claude Code persisting preferredLocation). Instead, the seed
        # lives at assets/vscode/settings.json and gets copied onto the real
        # file on every rebuild by the activation hook below. Drift between
        # rebuilds is inspected with `vscode-settings-diff`.
      };
    };

    # Install the seeder on PATH so it can be re-run by hand at any time.
    home.packages = lib.optionals cfg.vscode.enable [ vscodeSettingsSeed ];

    # Overwrite ~/.config/Code/User/settings.json with the seed on every
    # home-manager switch. Runs after writeBoundary so the Code/User/ directory
    # exists and any stale symlink from a previous generation has been cleaned.
    home.activation = lib.optionalAttrs cfg.vscode.enable {
      seedVSCodeSettings = hm.dag.entryAfter [ "writeBoundary" ] ''
        $DRY_RUN_CMD ${vscodeSettingsSeed}/bin/vscode-settings-seed
      '';
    };
  };
}
