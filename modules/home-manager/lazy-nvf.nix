{ config, lib, pkgs, inputs, ... }:

with lib;

let
  cfg = config.modules.lazy-nvf;
in
{
  imports = [ inputs.nvf.homeManagerModules.default ];

  options.modules.lazy-nvf = {
    enable = mkEnableOption "LazyVim-equivalent neovim via nvf" // {
      default = true;
    };

    colorscheme = mkOption {
      type = types.str;
      default = "dracula";
      description = "Colorscheme to apply. Must match a plugin listed in extraPlugins or a native nvf theme.";
    };

    picker = mkOption {
      type = types.enum [ "fzf-lua" "telescope" ];
      default = "fzf-lua";
      description = "Which fuzzy picker to wire keymaps and LSP actions through.";
    };

    autoOpenTree = mkOption {
      type = types.bool;
      default = false;
      description = "Open neo-tree automatically when nvim starts in a directory.";
    };
  };

  config = mkIf cfg.enable {
    programs.nvf = {
      enable = true;

      settings.vim = {
        viAlias = true;
        vimAlias = true;

        # Leader matches LazyVim default
        globals.mapleader = " ";

        # Editor defaults
        options = {
          tabstop = 2;
          shiftwidth = 2;
          expandtab = true;
          smartindent = true;
          number = true;
          relativenumber = true;
          wrap = false;
          ignorecase = true;
          smartcase = true;
          termguicolors = true;
          signcolumn = "yes";
          updatetime = 250;
          timeoutlen = 300;
          scrolloff = 8;
          sidescrolloff = 8;
          clipboard = "unnamedplus";
          undofile = true;
          mouse = "a";
        };

        # Dracula via extraPlugins - nvf doesn't ship it natively
        theme.enable = false;
        extraPlugins = {
          dracula-nvim = {
            package = pkgs.vimPlugins.dracula-nvim;
            setup = ''
              require("dracula").setup({
                transparent_bg = false,
                italic_comment = true,
              })
              vim.cmd.colorscheme("${cfg.colorscheme}")
            '';
          };
        };

        # Language support - per-language LSP, treesitter, formatter, linter
        languages = {
          enableLSP = true;
          enableTreesitter = true;
          enableFormat = true;
          enableExtraDiagnostics = true;

          ts.enable = true;          # TypeScript, JavaScript, React
          nix.enable = true;
          lua.enable = true;
          bash.enable = true;
          markdown.enable = true;
          html.enable = true;        # Angular templates
          css.enable = true;
          tailwind.enable = true;
          python.enable = true;
          go.enable = true;
          rust.enable = true;
          yaml.enable = true;
          json.enable = true;
        };

        # Picker - choose at module-option level
        telescope.enable = cfg.picker == "telescope";
        fzf-lua = mkIf (cfg.picker == "fzf-lua") {
          enable = true;
          profile = "default";
        };

        # VSCode-style file tree on the left
        filetree.neo-tree = {
          enable = true;
          setupOpts = {
            close_if_last_window = true;
            enable_git_status = true;
            enable_diagnostics = true;
            window = {
              position = "left";
              width = 35;
            };
            filesystem = {
              follow_current_file.enabled = true;
              use_libuv_file_watcher = true;
              filtered_items = {
                visible = false;
                hide_dotfiles = false;
                hide_gitignored = true;
              };
            };
            default_component_configs = {
              indent = {
                with_markers = true;
                with_expanders = true;
              };
              git_status.symbols = {
                added = "";
                modified = "";
                deleted = "";
                renamed = "";
                untracked = "";
                ignored = "";
                unstaged = "";
                staged = "";
                conflict = "";
              };
            };
          };
        };

        # Treesitter
        treesitter = {
          enable = true;
          fold = true;
          context.enable = true;
          indent.enable = true;
          textobjects.enable = true;
        };

        # LSP
        lsp = {
          enable = true;
          formatOnSave = true;
          lspkind.enable = true;
          lightbulb.enable = true;
          lspsaga.enable = false;
          trouble.enable = true;
          lspSignature.enable = true;
          otter-nvim.enable = true;
          nvim-docs-view.enable = false;
        };

        # Completion - blink.cmp, modern and fast
        autocomplete.blink-cmp = {
          enable = true;
          setupOpts = {
            keymap.preset = "default";
            completion.documentation.auto_show = true;
          };
        };

        # Snippets
        snippets.luasnip.enable = true;

        # Git
        git = {
          enable = true;
          gitsigns.enable = true;
          gitsigns.codeActions.enable = true;
        };

        # Visual
        visuals = {
          nvim-web-devicons.enable = true;
          indent-blankline.enable = true;
          fidget-nvim.enable = true;
          highlight-undo.enable = true;
          rainbow-delimiters.enable = true;
        };

        # Statusline and tabline
        statusline.lualine = {
          enable = true;
          theme = "auto";
        };

        tabline.nvimBufferline.enable = true;

        # UI
        ui = {
          borders.enable = true;
          noice.enable = true;
          colorizer.enable = true;
          illuminate.enable = true;
          breadcrumbs.enable = true;
          smartcolumn.enable = true;
          fastaction.enable = true;
          nvim-ufo.enable = true;
        };

        # Keybindings
        binds = {
          whichKey.enable = true;
          cheatsheet.enable = true;
        };

        # Utility
        utility = {
          motion.flash-nvim.enable = true;
          surround.enable = true;
          preserve-view.enable = true;
          nvim-biscuits.enable = true;
          snacks-nvim.enable = true;
          undotree.enable = true;
          outline.aerial-nvim.enable = true;
        };

        # Notes
        notes.todo-comments.enable = true;

        # Terminal
        terminal.toggleterm = {
          enable = true;
          lazygit.enable = true;
        };

        # Dashboard
        dashboard.alpha.enable = true;

        # Auto-open neo-tree on startup when directory is opened
        luaConfigRC.auto-open-tree = mkIf cfg.autoOpenTree ''
          vim.api.nvim_create_autocmd("VimEnter", {
            callback = function()
              if vim.fn.argc() == 1 and vim.fn.isdirectory(vim.fn.argv(0)) == 1 then
                vim.cmd("Neotree toggle")
              end
            end,
          })
        '';

        # Keymaps - picker commands switch based on cfg.picker
        keymaps =
          let
            findFiles = if cfg.picker == "fzf-lua" then "<cmd>FzfLua files<cr>" else "<cmd>Telescope find_files<cr>";
            liveGrep = if cfg.picker == "fzf-lua" then "<cmd>FzfLua live_grep<cr>" else "<cmd>Telescope live_grep<cr>";
            buffers = if cfg.picker == "fzf-lua" then "<cmd>FzfLua buffers<cr>" else "<cmd>Telescope buffers<cr>";
            helpTags = if cfg.picker == "fzf-lua" then "<cmd>FzfLua help_tags<cr>" else "<cmd>Telescope help_tags<cr>";
            oldfiles = if cfg.picker == "fzf-lua" then "<cmd>FzfLua oldfiles<cr>" else "<cmd>Telescope oldfiles<cr>";
            docSymbols = if cfg.picker == "fzf-lua" then "<cmd>FzfLua lsp_document_symbols<cr>" else "<cmd>Telescope lsp_document_symbols<cr>";
            lspDefinitions = if cfg.picker == "fzf-lua" then "<cmd>FzfLua lsp_definitions<cr>" else "<cmd>Telescope lsp_definitions<cr>";
            lspReferences = if cfg.picker == "fzf-lua" then "<cmd>FzfLua lsp_references<cr>" else "<cmd>Telescope lsp_references<cr>";
            lspImpls = if cfg.picker == "fzf-lua" then "<cmd>FzfLua lsp_implementations<cr>" else "<cmd>Telescope lsp_implementations<cr>";
            codeAction = if cfg.picker == "fzf-lua" then "<cmd>FzfLua lsp_code_actions<cr>" else "<cmd>lua vim.lsp.buf.code_action()<cr>";
          in
          [
            # File navigation
            { key = "<leader>ff"; mode = "n"; action = findFiles; desc = "Find files"; }
            { key = "<leader>fg"; mode = "n"; action = liveGrep; desc = "Grep project"; }
            { key = "<leader>fb"; mode = "n"; action = buffers; desc = "Find buffer"; }
            { key = "<leader>fh"; mode = "n"; action = helpTags; desc = "Help tags"; }
            { key = "<leader>fr"; mode = "n"; action = oldfiles; desc = "Recent files"; }
            { key = "<leader>fs"; mode = "n"; action = docSymbols; desc = "Document symbols"; }

            # File tree
            { key = "<leader>e"; mode = "n"; action = "<cmd>Neotree toggle<cr>"; desc = "File tree"; }
            { key = "<leader>E"; mode = "n"; action = "<cmd>Neotree reveal<cr>"; desc = "Reveal current file in tree"; }

            # Buffer navigation
            { key = "<S-h>"; mode = "n"; action = "<cmd>BufferLineCyclePrev<cr>"; desc = "Previous buffer"; }
            { key = "<S-l>"; mode = "n"; action = "<cmd>BufferLineCycleNext<cr>"; desc = "Next buffer"; }
            { key = "<leader>bd"; mode = "n"; action = "<cmd>bdelete<cr>"; desc = "Delete buffer"; }

            # Window navigation
            { key = "<C-h>"; mode = "n"; action = "<C-w>h"; desc = "Left window"; }
            { key = "<C-j>"; mode = "n"; action = "<C-w>j"; desc = "Down window"; }
            { key = "<C-k>"; mode = "n"; action = "<C-w>k"; desc = "Up window"; }
            { key = "<C-l>"; mode = "n"; action = "<C-w>l"; desc = "Right window"; }

            # LSP
            { key = "gd"; mode = "n"; action = lspDefinitions; desc = "Go to definition"; }
            { key = "gr"; mode = "n"; action = lspReferences; desc = "References"; }
            { key = "gi"; mode = "n"; action = lspImpls; desc = "Implementations"; }
            { key = "K"; mode = "n"; action = "<cmd>lua vim.lsp.buf.hover()<cr>"; desc = "Hover docs"; }
            { key = "<leader>ca"; mode = "n"; action = codeAction; desc = "Code action"; }
            { key = "<leader>rn"; mode = "n"; action = "<cmd>lua vim.lsp.buf.rename()<cr>"; desc = "Rename symbol"; }

            # Diagnostics
            { key = "<leader>xx"; mode = "n"; action = "<cmd>Trouble diagnostics toggle<cr>"; desc = "Diagnostics list"; }
            { key = "<leader>xd"; mode = "n"; action = "<cmd>Trouble diagnostics toggle filter.buf=0<cr>"; desc = "Buffer diagnostics"; }

            # Git
            { key = "<leader>gg"; mode = "n"; action = "<cmd>LazyGit<cr>"; desc = "LazyGit"; }
            { key = "<leader>gb"; mode = "n"; action = "<cmd>Gitsigns blame_line<cr>"; desc = "Git blame line"; }

            # Terminal
            { key = "<leader>tt"; mode = "n"; action = "<cmd>ToggleTerm direction=float<cr>"; desc = "Float terminal"; }
            { key = "<leader>th"; mode = "n"; action = "<cmd>ToggleTerm direction=horizontal<cr>"; desc = "Horizontal terminal"; }

            # Save and quit
            { key = "<leader>w"; mode = "n"; action = "<cmd>write<cr>"; desc = "Save"; }
            { key = "<leader>q"; mode = "n"; action = "<cmd>quit<cr>"; desc = "Quit"; }

            # Clear search highlight
            { key = "<Esc>"; mode = "n"; action = "<cmd>nohlsearch<cr>"; desc = "Clear highlight"; }

            # Reserved for voice-driven bindings
            # { key = "<leader>vs"; mode = "n"; action = "..."; desc = "Speak selection"; }
          ];
      };
    };
  };
}
