{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.just;
in
{
  options.modules.just = {
    enable = mkEnableOption "global justfile and j alias";
  };

  config = mkIf cfg.enable {
    programs.zsh.shellAliases.j = "just -g";

    home.packages = [ pkgs.gum ];

    xdg.configFile."just/justfile".text = ''
      # Show available recipes
      default:
          @just --list

      # Initialize a project. Pass go or ts, or pick interactively.
      [no-cd]
      init lang="":
          #!/usr/bin/env bash
          set -e
          lang="{{lang}}"
          [ -z "$lang" ] && lang=$(gum choose go ts)
          case "$lang" in
            go)
              name=$(basename "$(pwd)")
              go mod init "$name"
              if [ ! -f main.go ]; then
                printf 'package main\n\nimport "fmt"\n\nfunc main() {\n\tfmt.Println("hello")\n}\n' > main.go
              fi
              ;;
            ts)
              npm init -y
              npm install --save-dev typescript @types/node tsx
              npx tsc --init
              mkdir -p src
              [ -f src/index.ts ] || printf 'console.log("hello");\n' > src/index.ts
              npm pkg set scripts.dev="tsx src/index.ts"
              npm pkg set scripts.build="tsc"
              ;;
            *)
              echo "unknown lang: $lang (try: go, ts)" >&2
              exit 1
              ;;
          esac

      # Run the project in the current directory
      [no-cd]
      run:
          #!/usr/bin/env bash
          set -e
          if [ -f main.go ]; then
              go run main.go
          elif [ -f package.json ]; then
              npm run dev
          elif [ -f Cargo.toml ]; then
              cargo run
          else
              echo "no recognized project in $(pwd)" >&2
              exit 1
          fi

      # Build the project in the current directory
      [no-cd]
      build:
          #!/usr/bin/env bash
          set -e
          if [ -f go.mod ]; then
              go build
          elif [ -f package.json ]; then
              npm run build
          elif [ -f Cargo.toml ]; then
              cargo build
          else
              echo "no recognized project in $(pwd)" >&2
              exit 1
          fi

      # Install or refresh dependencies in the current directory
      [no-cd]
      install:
          #!/usr/bin/env bash
          set -e
          if [ -f go.mod ]; then
              go mod tidy
          elif [ -f package.json ]; then
              npm install
          elif [ -f Cargo.toml ]; then
              cargo fetch
          else
              echo "no recognized project in $(pwd)" >&2
              exit 1
          fi

      # Stage everything and commit. Prompts for a message if none given.
      [no-cd]
      commit *message="":
          #!/usr/bin/env bash
          set -e
          msg="{{message}}"
          [ -z "$msg" ] && msg=$(gum input --placeholder "commit message")
          [ -z "$msg" ] && { echo "no message" >&2; exit 1; }
          git add .
          git commit -m "$msg"
    '';
  };
}
