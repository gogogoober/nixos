# Show available recipes
default:
    @just --list

# Format all nix files using the flake's formatter
format:
    nix fmt
