logfile := "/tmp/nixos-switch.log"
tick := "30" # Seconds between rebuild progress lines
extra := "" # Extra nixos-rebuild flags, e.g. --install-bootloader
keep := "5" # System generations `just clean` keeps
journal := "30d" # Journal history `just clean` keeps
scratch := "4" # Hours an agent scratchpad may sit idle before `just clean` takes it

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

# Delete all but the newest `keep` system generations and reclaim everything else
clean:
    #!/usr/bin/env bash
    set -euo pipefail
    sudo -v
    free() { df --output=avail -BG / | tail -1 | tr -dc 0-9; }
    before=$(free)

    echo "==> Deleting system generations older than the last {{ keep }}"
    sudo nix-env --delete-generations +{{ keep }} -p /nix/var/nix/profiles/system

    # Clearing caches first releases their gc roots before the sweep
    echo "==> Clearing build caches"
    rm -rf ~/.cache/nix
    go clean -cache 2>/dev/null || true

    echo "==> Clearing agent scratchpads idle more than {{ scratch }}h"
    idle_minutes=$(( {{ scratch }} * 60 ))
    for session in /tmp/claude-$(id -u)/*/*/; do
      [ -d "$session" ] || continue
      # Nothing touched inside the window means the session is over
      if [ -z "$(find "$session" -mmin -$idle_minutes -print -quit)" ]; then
        du -sh "$session" | sed 's/^/    freeing /'
        rm -rf "$session"
      fi
    done

    echo "==> Collecting garbage"
    sudo nix-collect-garbage
    nix-collect-garbage

    # Hardlinks identical files across the store, slow on a big store
    echo "==> Deduplicating the store"
    sudo nix-store --optimise

    echo "==> Vacuuming the journal to {{ journal }}"
    sudo journalctl --vacuum-time={{ journal }} 2>&1 | tail -1

    # Drops boot entries for the generations just deleted
    echo "==> Refreshing the boot menu"
    sudo /run/current-system/bin/switch-to-configuration boot

    after=$(free)
    echo "==> Reclaimed $((after - before)) GiB, $after GiB free"
    nixos-rebuild list-generations

# Run flake checks
test:
    nix flake check

# Update every flake input, rebuild, then reclaim space
update:
    nix flake update
    sudo nixos-rebuild switch --flake . -L 2>&1 | tee /tmp/nixos-upgrade.log
    just clean
