# Upgrade audit ledger

Written by the `find-upgrades` skill. One row per choice audited, newest first.
A choice missing from this table has never been audited, which is what makes it
a priority next run.

The revisit condition is the point of the row: a later run checks whether that
condition fired instead of researching the whole question again.

| Checked | Choice | Where | Verdict | Revisit when |
| --- | --- | --- | --- | --- |
| 2026-09-14 | Speech-to-text model and backend, `small.en` on Vulkan over `tiny.en` on CPU | `modules/nixos/stt.nix` | upgrade, applied in generation 44 | whisper.cpp ships an encoder that shrinks with distillation, or sherpa-onnx Parakeet gains a Nix-packaged server. PRD 21 has the measurements. |
| 2026-09-09 | linux-surface kernel over stock nixpkgs | `hosts/surface-go-3/` | hold, declined | pen input becomes a requirement, and a binary cache or remote builder exists to absorb the 3+ hour build. |
