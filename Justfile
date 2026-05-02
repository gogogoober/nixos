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

# Rebuild a host by short name (surface or dell)
rebuild host:
    #!/usr/bin/env bash
    case "{{host}}" in
      surface) flake_host="surface-go-3" ;;
      dell)    flake_host="old-dell" ;;
      *)       flake_host="{{host}}" ;;
    esac
    sudo nixos-rebuild switch --flake /home/hugo/nixos#$flake_host

# Run flake checks
test:
    nix flake check
