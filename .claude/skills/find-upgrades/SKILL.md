---
name: find-upgrades
description: Use when asked to find upgrades, look for better options, or confirm the tools this config already picked are still the right ones — speech models, backends, packages, flake idiom, anything pinned. A research-only audit meant to run every one to three months. It reports and never changes the config.
---

# Find upgrades

A periodic audit of the choices this config has already made. Work out what the
repo is currently betting on, check whether the world moved since that bet was
placed, and report. You change nothing.

**"Everything still holds" is a successful run.** Recommending a change you
cannot defend is worse than recommending none.

## Rules

- Never edit a module, never run `just rebuild`. The only files you write are
  the ledger and, once the user agrees to a change, a PRD in `.ai/prds/`.
- Audit a fixed budget of choices per run: four by default, or the number the
  user named. If they named an area instead (`stt`, `flake`, `tts`), audit only
  that and ignore the budget.
- Judge every candidate against the host it would land on. Read
  `docs/hosts/<hostname>.md` before forming an opinion — a model that is free on
  `dell-old` is disqualified by the fanless 5 W budget on `surface-go-3`.
- Cite a source for every claim: a release note, a nixpkgs option, a benchmark,
  a commit. Never recommend from memory, and say so plainly when the evidence is
  thin.
- Nothing here is a hardcoded list of what to check. Derive the candidates from
  the repo each run so the skill does not rot as the config grows.

## 1. Read the ledger

`.ai/upgrades/ledger.md` records every choice previously audited, its verdict,
and the condition that should reopen it. Read it first.

If the newest row is under thirty days old, say so and ask whether to run
anyway. One to three months is the intended cadence.

## 2. Find the candidates

Sweep the repo for places where it committed to one option over others. These
greps are the starting point, not the whole job — anything that reads as a
decision counts.

```
grep -rn "fetchurl\|fetchFromGitHub\|fetchzip" --include="*.nix" .   # pinned upstream artifacts
grep -rn "unstable\." --include="*.nix" .                            # packages that escaped stable
grep -rn "engines\? = \|mkOption" --include="*.nix" modules          # enumerated backends and knobs
grep -rln "systemd.services\|writeShellApplication" modules          # mechanisms a declarative option might now replace
sed -n '/inputs = {/,/};/p' flake.nix                                # third-party inputs and branch pins
```

Five recurring categories, roughly in order of how often they pay off:

**Pinned artifacts.** Model weights, voices, presets fetched by URL and hash.
Check the upstream project for a newer or better-suited release. This is where
speech-to-text and text-to-speech live.

**Backends.** The engine behind a feature, whether or not the module exposes a
choice. Has a competitor overtaken it, or has the current one gained something
the config is not using?

**Stable versus unstable.** For each `pkgs.unstable.*`, check whether stable
caught up — moving back shrinks the closure and the risk. In the other
direction, check whether the pinned nixpkgs release branch has a successor out
yet, and whether home-manager has a matching release.

**Scripts that could be options.** The repo prefers a declarative option over a
watcher script. For each custom service, re-check whether nixpkgs has since
grown an option that does the same job. Establish it, do not assume it.

**Idiom.** flake-parts, home-manager, and module conventions move. Deprecation
and rename warnings surface with `just test`; run it if the user is willing to
wait.

## 3. Drop what is already settled

Before researching anything, check it against the record:

- The dead-end sections in `docs/hosts/*.md`, which carry dates and reasons.
- `.ai/prds/`, which is the record of what was tried and why.
- The ledger's revisit conditions.

If a candidate was already rejected, it comes back only when its revisit
condition actually fired — a new release, a hardware change, a measurement that
no longer holds. Name that trigger in the report. Otherwise drop it silently.

## 4. Rank and cut to budget

Never audited beats least recently audited, and both beat a choice whose
upstream has been quiet. Cut to the budget and say in the report which
candidates you set aside, one line each, so the user can pull one back in.

## 5. Research each one

For each survivor: what is pinned now, what exists instead, what it would cost
on this host, and what it would buy. Prefer a measurement over a claim. If the
honest answer needs a benchmark on the actual hardware, say that rather than
guessing — the speech PRDs show the shape that measurement takes.

Land on one of three verdicts.

**Hold.** The current choice is still right. Give the reason and the condition
that would change it.

**Upgrade.** A better option exists and the evidence supports it. Name the
change, the file, and what the user gives up.

**Investigate.** Promising but unproven on this hardware. Say what would settle
it.

## 6. Report, then write the ledger

Report in the conversation following the user's response format: one short
paragraph per candidate, the choice as the title, the verdict in the first
sentence. Put files, URLs, versions, and model names in the appendix.

Then append one ledger row per candidate, newest rows at the top of the table.
Keep the revisit condition specific enough that a future run can check it in a
minute.

A durable, host-specific rejection also earns a short paragraph in that host's
dead-end section, in the style already there: what was considered, when, why
not, and what would reopen it.

Stop there. Writing the PRD and touching the config are separate asks.
