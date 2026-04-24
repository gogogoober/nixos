{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.modules.claude;

  # Wraps the raw seed script with the Nix-store path to the seed tree baked
  # in. Same pattern as vscodeSettingsSeed in editors.nix: the raw script
  # lives at modules/home-manager/scripts/ so it stays editable and runnable
  # outside the Nix build; this wrapper is what lands on PATH and what the
  # activation hook invokes.
  claudeSkillsSeed = pkgs.writeShellApplication {
    name = "claude-skills-seed";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      export CLAUDE_SEED=${./../../assets/claude}
      # shellcheck source=/dev/null
      source ${./scripts/claude-skills-seed.sh}
    '';
  };
in
{
  options.modules.claude = {
    enable = mkEnableOption "Claude Code baseline (CLAUDE.md + skills/)" // {
      default = true;
    };
  };

  config = mkIf cfg.enable {
    # Install the seeder on PATH so it can be re-run by hand at any time.
    home.packages = [ claudeSkillsSeed ];

    # Re-seed ~/.claude/{CLAUDE.md, skills/<seeded>} on every home-manager
    # switch. Per-file-by-name semantics: only files/dirs present in
    # assets/claude/ are touched. See claude-skills-seed.sh for details.
    home.activation.seedClaudeSkills = hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${claudeSkillsSeed}/bin/claude-skills-seed
    '';
  };
}
