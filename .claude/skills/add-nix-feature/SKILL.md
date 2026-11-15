---
name: add-nix-feature
description: Add a feature to this NixOS config in the right place, the way this repo builds things. Works out the host, looks for a declarative option first, decides whether it is a host setting, a change to an existing module, or a new module, hands the edit to write-code, proves it with just test, and hands over the just rebuild command. Use when the user says /add-nix-feature, "add X to my config", "turn on X", "set up X on this machine", "change the X module", or asks for any new setting, package or module in the nixos repo. Never runs just rebuild, never commits, never writes a PRD. Inside the nixos repo this wins over write-code for feature requests, and calls write-code itself; find-upgrades owns audits.
model: opus
---

# Add nix feature

Goal: a feature lands where the repo's conventions say it belongs and evaluates on every host.
Done means just test passes, the user has the rebuild command, and knows how to check it works.

## Place in workflow
- Workflow: standalone, repo scope: only this repo uses it, so it lives here, not in user scope.
- After: none · Before: none
- Calls: `plan-code` (when placement is unclear), `write-code` (every edit). `no-secrets` fires on its own.

Side effects: edits tracked files through write-code, `git add -N` on new files. Never runs
`just rebuild`, never commits.

The rules for where things go are in the repo CLAUDE.md (module contract, host versus module,
look for an option before a script). Apply them; never restate them in output.

## 1. Host and inventory
Run `scripts/inventory.sh <keywords>` from the repo root, keywords taken from the request.
Read the host doc it names, and any PRD or host doc it lists under mentions.
Done when: you know the host, what it turns on, which modules touch the feature, and any dead
end that already rules it out.

## 2. Understand the feature
Get, from the request or one round of questions: what it does, which hosts get it, and how the
user will see it work. A dead end from phase 1 that covers it: say so and stop unless the user
says its reopen condition fired.
Done when: one sentence each for what, hosts, and the check.

## 3. Find the option
Run `scripts/find-option.sh <keyword>`. Read the hits that look right. Load
`steps/find-option.md` only when the hits are empty or none fits.
Done when: a named option does the job, or you established that none does.

## 4. Place it
Pick one kind and fill `templates/placement.md`:
- **Setting**: an option or package value. Lives in the module that owns that concern, or in
  the host file when the value would be wrong on another machine.
- **Module change**: extends a module the inventory lists. New knobs are options with no
  default when the host must supply them.
- **New module**: one concern, the module contract, imported in the matching `default.nix`,
  switched on in each target host. A system module that has a home-manager half flips it.
Placement unclear, or two concerns: run `plan-code` with what you have instead of guessing.
Gate: wait for approval of the placement card, or for plan-code's go.
Done when: the user approved where it goes.

## 5. Write it
Run `write-code` with `templates/handoff.md` filled. Small settings will be write-code's
trivial tier.
After it reports: `git add -N` every new file (the flake ignores untracked files), then
`just format` and `just test`. A failure goes back to write-code with the error.
Done when: just test passes and the diff touches only the placed files.

## 6. Hand over the rebuild
Fill `templates/rebuild.md`.
Gate: wait for the user to say the rebuild ran. On failure, read `/tmp/nixos-switch.log`,
find the first error, and go back to phase 5.
Done when: the rebuild succeeded.

## 7. Report and learn
Fill `templates/report.md`. If the run hit a quirk a future reader would rediscover, propose
the exact line and where it goes: the host doc for this machine, the repo CLAUDE.md gotchas
for any machine. Save only on approval.

## Rules
- Every value comes from the host or a named option; nothing machine-specific in a module.
- A new systemd unit wanted by `multi-user.target` gets the reboot note in the rebuild handover.
- Use `pkgs.unstable` only with a one-line reason the user agreed to.
