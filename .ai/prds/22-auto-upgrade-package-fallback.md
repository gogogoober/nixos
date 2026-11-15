# Auto-Upgrade Package Fallback PRD

## Goal

Stop one broken package upstream from blocking the whole weekly upgrade. When
a build fails, hold the failing package at the revision it last built at,
rebuild, and switch. Nothing is pinned by hand, and the hold disappears on its
own once nixpkgs is fixed.

## What Actually Happened, 2026-11-12

The weekly upgrade ran at 18:30 after the tablet came back from being off
since September 22, caught up by the timer's `Persistent=true`. It failed at
19:15, 32 minutes and 48 minutes of CPU in, at 2588 of 2621 paths.

One derivation broke it. VS Code 1.144.0 landed on `nixos-26.05` and its patch
phase removes a bundled ripgrep binary that upstream stopped shipping:

```
vscode> rm: cannot remove 'resources/app/node_modules/@vscode/ripgrep/bin/rg': No such file or directory
error: Cannot build '/nix/store/v3db55bv47zfj5dh79iz7x636c5l7h0g-vscode-1.144.0.drv'.
       Reason: builder failed with exit code 1.
```

Six dependents then failed with `1 dependency failed`, up through
`home-manager-path`, `etc`, and the system closure. Nothing switched, so the
running system was never at risk. The cost was the CPU time and the fact that
the failure was invisible until someone went looking.

Being on stable did not help and could not have: VS Code is a repackaged
upstream binary, so nixpkgs keeps bumping it on release branches. Staying a
release behind is not available either, since a release is supported only until
about a month after the next one.

## Design

`modules/nixos/auto-upgrade.nix` owns the weekly upgrade now. It keeps
`system.autoUpgrade` for the timer, the Monday schedule, the jitter and the
`ConditionACPower` gate, and replaces only the service script.

The script runs two passes:

1. **Clean pass.** `nixos-rebuild switch` against the whole channel tip,
   including anything held back last week. Success deletes the held-back
   record, which is how a fixed package stops being held without anyone
   noticing it was.
2. **Fallback pass, only on failure.** Parse the log for derivations whose own
   builder failed, ignoring the dependents that failed with them. Map each to
   a nixpkgs attribute, generate a wrapper flake that re-evaluates this host's
   configuration with those attributes taken from an older revision, and switch
   to that.

The revision a package falls back to is the one the running system was built
from, read at eval time from `config.system.nixos.revision`, because a package
that just started failing at the tip still built at the revision the running
system came from. Packages already held keep the revision recorded in
`/var/lib/nixos-upgrade/held-back`, since after a fallback switch the running
system's revision is the tip that broke them.

Guards, in order: no identifiable root cause aborts, more than
`maxHeldBack` (3) root causes aborts on the grounds that the break is in a
toolchain rather than a leaf package, and an attribute that does not exist at
the fallback revision aborts. A failed fallback pass switches nothing, so the
worst outcome is the same wasted CPU as before.

## Why Not The Alternatives

**Pin the volatile packages by hand.** Works, but it is a list to maintain and
it keeps holding a package long after upstream fixed it.

**Lag the channel by two weeks.** Does not help. Lagging picks the tree as it
stood on an earlier date, so a break that landed on the 8th is still in the
tree built on the 22nd, and the fix that landed on the 10th is not.

**Drop `--recreate-lock-file` and bump the lock deliberately.** The honest
alternative, and still worth doing some day, but it turns the weekly run into a
no-op and moves the work to a manual step.

## Validation, 2026-11-14

The script was exercised case by case against the real failure log, with the
state directory redirected, the clean pass short-circuited, and the final
switch replaced by a dry build.

| Case | Setup | Result |
| --- | --- | --- |
| Happy path | real log, target locked at the tip | guard passes, plan ends at `nixos-system-...26.05.20261108.ac588ef.drv` with 10 derivations left, `held-back` written |
| No root cause | log with only `1 dependency failed` | exit 1, "no single package to blame" |
| Too many | four synthetic root causes | exit 1, "4 packages failed, too many to hold back" |
| Missing attribute | root cause named `zzz-nonexistent-pkg` | exit 1, "nothing to hold it back to" |
| No-op guard | target still locked at the running revision | exit 1, "would rebuild the running revision" |
| Held-back reuse | `held-back` pre-seeded with another revision | that revision used instead of the running one |
| Two revisions | two root causes, one already held | two `held-` inputs generated, each override pointing at its own |

Supporting checks:

- The generated service and timer are byte-identical to the running ones once
  store hashes are stripped, so moving `system.autoUpgrade` out of
  `common.nix` changed the schedule, jitter, persistence, `ConditionACPower`
  and hardening not at all. Only the script `ExecStart` runs differs.
- The clean pass now carries `--refresh` to match the flags upstream's script
  passed. Upstream also passes `--upgrade`, which is a no-op for a flake.
- `pkgs.vscode` and `pkgs.vscode-fhs` both come back `1.119.0` under the
  overlay, so nixpkgs resolves the FHS wrapper through the package set
  fixpoint and overriding the one attribute is enough.
- Both generated wrapper flakes, one revision and two, parse.
- `config.system.nixos.revision` bakes the full 40 character revision into the
  script, so it needs no `nixos-version` at runtime. The first version called
  `nixos-version --json | jq`, neither of which is on the unit's PATH.
- The whole system builds, which is also what runs the shellcheck that
  `writeShellApplication` wraps.
- `just test` passes but does not cover this: `nix flake check` on this flake
  checks `nixosModules`, `apps`, `checks`, `legacyPackages` and `overlays` and
  never evaluates `nixosConfigurations`. A host config only gets validated by
  building it.

What is not validated: an actual fallback `switch`, since that would change
the system. The dry build is as far as this goes without applying.

## Known Fragility

The fallback pass depends on the clean pass having rewritten the store copy's
`flake.lock` in place. That in-place rewrite is a side effect of
`--recreate-lock-file`, which is already deprecated. If a future nix drops it,
the fallback pass silently rebuilds the old tree and reports success, which is
worse than failing, so the script evaluates the wrapper's
`config.system.nixos.revision` and aborts when it matches the running one.
That guard is tested, but it is a backstop: losing the in-place rewrite still
means no upgrades, just loud ones.

## Open Questions

- The module defaults to `enable = true`, which deviates from the opt-in per
  host convention. It preserves the previous behaviour, since `autoUpgrade`
  lived in `common.nix` and was therefore unconditional on both hosts. Worth
  deciding whether to make it an explicit host switch instead.
- Nothing surfaces a held-back package to the user. The bar indicator from the
  same session reports success or failure but not "succeeded with vscode held
  at 1.119.0".
- A package could stay held indefinitely if upstream never fixes it, and the
  only trace is a file in `/var/lib/nixos-upgrade`.

## Out of Scope

- Holding back a library or a compiler. The `maxHeldBack` cap and the
  attribute existence check are deliberately crude, and a toolchain break
  should fail loudly rather than be worked around.
- Deciding which packages are worth pinning permanently.

## Target Files

- `modules/nixos/auto-upgrade.nix`, new, owns the service script and the
  fallback flake template
- `modules/nixos/common.nix`, lost its `system.autoUpgrade` block and the
  `ConditionACPower` line
- `modules/nixos/default.nix`, imports the new module
