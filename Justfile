logfile := "/tmp/nixos-switch.log"
tick := "30" # Seconds between rebuild progress lines
extra := "" # Extra nixos-rebuild flags, e.g. --install-bootloader

# Show available recipes
default:
    @just --list

# Format all nix files with nixfmt-tree (the flake's formatter)
format:
    nix fmt

# Generate an ed25519 SSH key and copy the public key to the clipboard
ssh-key name="id_ed25519" comment="juicebox.salinas@gmail.com":
    ssh-keygen -t ed25519 -C "{{comment}}" -f ~/.ssh/{{name}}
    wl-copy < ~/.ssh/{{name}}.pub
    @echo "Public key for {{name}} copied to clipboard"

# Commit staged changes with the rest of the line as the message
commit +message:
    git commit -m "{{message}}"

# Build first, then commit as "<generation> - <message>" only once the build succeeds
rebuild +message:
    #!/usr/bin/env bash
    set -euo pipefail
    sudo -v
    git add -A
    nix fmt
    git add -A
    git diff --cached --stat
    git diff --cached -U0 -- '*.nix'
    echo "NixOS rebuilding..."
    sudo nixos-rebuild switch --flake . {{ extra }} > {{ logfile }} 2>&1 &
    build=$!
    while kill -0 $build 2>/dev/null; do
      sleep {{ tick }}
      echo "  $(grep -c 'copying path' {{ logfile }} || true) fetched, $(grep -c '^building ' {{ logfile }} || true) built"
    done
    wait $build || { grep --color -iE '^\s*(error|failed)' {{ logfile }} || tail -n 20 {{ logfile }}; exit 1; }
    git commit -m "$(nixos-rebuild list-generations --json | jq -r '.[] | select(.current) | .generation') - {{message}}"

# Tail the log from the last rebuild
log:
    tail -f {{ logfile }}

# Run flake checks
test:
    nix flake check

# Update every flake input, rebuild, and stream logs inline and to file
update:
    nix flake update
    sudo nixos-rebuild switch --flake . -L 2>&1 | tee /tmp/nixos-upgrade.log
