---
name: no-secrets
description: Use when creating or editing any tracked file in this repo — Nix configs, home-manager modules, dotfiles, scripts. Treats the repo as public, keeps secrets and personal identifiers (beyond name and email) out of version control, and stops to ask before inlining anything sensitive.
---

Treat every file you write here as public.

The user's name and email are fine where a config needs them, like git user config. Nothing else identifying belongs in tracked files: no other personal data, no machine fingerprints, no credentials of any kind. Disk UUIDs in `hosts/*/hardware.nix` are the one accepted exception, since Nix needs them.

If a config genuinely requires a secret, do not inline it or invent a plausible fake. Stop and ask, or suggest wiring up `agenix` or `sops-nix`.
