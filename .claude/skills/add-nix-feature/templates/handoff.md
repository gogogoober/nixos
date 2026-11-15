# Template: handoff to write-code

Passed as write-code's task, after the placement card was approved.

```
Change in the nixos flake, placement approved:
{placement card appendix, the Edit / New file / Host switch lines}

Option used: {option or "own mechanism"}
Values: {each tunable and its value, and whether it lives in the host or the module}

Repo rules: follow the repo CLAUDE.md module contract and its hoisted-settings rule.
Build proof: `just format` then `just test`. This repo has no unit tests: skip the test
suggester and add none.
Do not run `just rebuild`, do not commit.
```
