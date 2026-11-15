# Step: find the option when the script finds nothing

The script only matches the keyword. Try these in order and stop at the first real hit.

1. Rerun `scripts/find-option.sh` with the upstream program name, the package attribute name,
   and the service's common name (`pipewire` for audio, `logind` for lid behaviour).
2. Check the package exists on the pinned release: `nix eval --raw nixpkgs#<name>.version`.
   A package with no module is a setting: add it to the owning module's package list.
3. Search the pinned trees for the program's config file name or binary, since many modules
   are named after a parent service:
   `rg -l '<binary or config file>' <nixpkgs>/nixos/modules <home-manager>/modules`.
   The two roots are printed in the script's section headers.
4. Web, when allowed: search.nixos.org options for the stable channel, and the home-manager
   options search. Prefer the pinned tree when they disagree.

None found: say so with what you searched. Then the mechanism is a module of our own:
`environment.etc` or `xdg.configFile` for a config file, `systemd.services` or
`systemd.user.services` for a daemon, `writeShellApplication` for a helper. Every value it
acts on still comes from the host.
