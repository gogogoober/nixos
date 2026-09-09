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

# Stage everything, commit with the given message, and rebuild the active host
rebuild +message:
    git add .
    -git commit -m "{{message}}"
    sudo nixos-rebuild switch --flake . --show-trace

# Run flake checks
test:
    nix flake check

# Update all flake inputs, rebuild, and stream logs inline and to file
update:
    sudo nixos-rebuild switch --flake . \
      --update-input nixpkgs \
      --update-input home-manager \
      --update-input disko \
      --update-input hyprland \
      --update-input fsel \
      --update-input flake-parts \
      -L \
      2>&1 | tee /tmp/nixos-upgrade.log
