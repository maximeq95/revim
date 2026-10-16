# revim's Neovim, as a nixvim module. Plugins, language servers, formatters and
# linters all come from nixpkgs: no plugin manager, no Mason.
{
  lib,
  pkgs,
  flavor,
  clipboard,
  ...
}:
let
  mkBind = options: mode: key: action: desc: {
    inherit mode key action;
    options = options // {
      inherit desc;
    };
  };
  bind = mkBind { };
  remap = mkBind { remap = true; };
  hunk = mkBind { expr = true; } "n";
  focusFiles = "<cmd>lua vim.system({ 'zellij', 'action', 'move-focus', 'left' })<cr>";
in
{
  viAlias = true;
  vimAlias = true;

  colorschemes.catppuccin = {
    enable = true;
    settings = {
      flavour = flavor;
      term_colors = true;
      integrations.barbar = true;
    };
  };

  globals = {
    mapleader = " ";
    maplocalleader = " ";
    # yazi is the file manager.
    loaded_netrw = 1;
    loaded_netrwPlugin = 1;
  }
  // lib.optionalAttrs (clipboard != null) { inherit clipboard; };

  clipboard = {
    register = "unnamedplus";
    providers.wl-copy.enable = clipboard == "wl-copy";
  };

  opts = {
    number = true;
    mouse = "a";
    expandtab = true;
    shiftwidth = 2;
    tabstop = 2;
    softtabstop = 2;
    smartindent = true;
    signcolumn = "yes";
    cursorline = true;
    scrolloff = 4;
    wrap = false;
    ignorecase = true;
    smartcase = true;
    undofile = true;
    autoread = true;
    confirm = true; # :q, :qa… on unsaved changes ask to save rather than fail
    splitright = true;
    splitbelow = true;
    showtabline = 2; # barbar's file tabs, even for a single file
    cmdheight = 0; # messages go to ui2's float (extraConfigLua)
    spelllang = "en";
    spelloptions = "camel";
    # The default, plus globals: where barbar keeps its tab order.
    sessionoptions = "blank,buffers,curdir,folds,globals,help,tabpages,winsize,terminal";
    updatetime = 200;
    timeoutlen = 300;
  };

  diagnostic.settings = {
    severity_sort = true;
    virtual_text = {
      spacing = 2;
      source = "if_many";
      prefix = "●";
    };
    float = {
      border = "rounded";
      source = true;
    };
  };

  plugins = {
    # Look & feel
    web-devicons.enable = true;
    barbar.enable = true; # one tab per open file
    lualine = {
      enable = true;
      settings.sections.lualine_x = [
        "lsp_status"
        "encoding"
        "filetype"
      ];
    };
    barbecue.enable = true; # breadcrumbs…
    navic.enable = true; # …fed by navic
    indent-blankline.enable = true;
    rainbow-delimiters.enable = true;
    colorizer.enable = true;
    todo-comments.enable = true;
    fidget.enable = true;
    notify.enable = true;
    which-key = {
      enable = true;
      settings.spec =
        lib.mapAttrsToList
          (key: group: {
            __unkeyed-1 = "<leader>${key}";
            inherit group;
          })
          {
            a = "AI / Claude";
            b = "File";
            c = "Code";
            f = "Find";
            g = "Git";
            q = "Session";
            s = "Search / replace";
            x = "Diagnostics";
          };
    };
    render-markdown = {
      enable = true;
      settings = {
        code = {
          width = "block";
          left_pad = 2;
          right_pad = 2;
        };
        latex.enabled = false;
      };
    };

    # Navigation
    telescope = {
      enable = true;
      extensions.fzf-native.enable = true;
      keymaps = {
        "<leader><space>" = "find_files";
        "<leader>ff" = "find_files";
        "<leader>fg" = "live_grep";
        "<leader>fb" = "buffers";
        "<leader>fh" = "help_tags";
        "<leader>fd" = "diagnostics";
        "<leader>fs" = "lsp_document_symbols";
        "<leader>fr" = "oldfiles";
        "<leader>fR" = "resume";
      };
    };
    flash.enable = true;
    aerial.enable = true;
    zellij-nav.enable = true;
    lastplace.enable = true;
    persistence.enable = true;
    trouble.enable = true;

    # Editing
    nvim-autopairs.enable = true;
    nvim-surround.enable = true;
    visual-multi = {
      enable = true;
      settings = {
        maps = {
          "Find Under" = "<C-d>";
          "Find Subword Under" = "<C-d>";
          "Select All" = "<C-S-l>";
        };
        show_warnings = 0;
      };
    };
    grug-far.enable = true;
    friendly-snippets.enable = true;
    blink-cmp = {
      enable = true;
      settings = {
        completion.documentation.auto_show = true;
        signature.enabled = true;
      };
    };
    treesitter = {
      enable = true;
      settings = {
        highlight.enable = true;
        indent.enable = true;
      };
    };
    treesitter-context.enable = true;
    helm.enable = true;
    lspconfig.enable = true;
    conform-nvim = {
      enable = true;
      autoInstall.enable = true;
      settings = {
        formatters_by_ft = {
          nix = [ "nixfmt" ];
          lua = [ "stylua" ];
          sh = [ "shfmt" ];
          toml = [ "taplo" ];
        }
        // lib.genAttrs [ "json" "jsonc" "markdown" "yaml" ] (_: [ "prettierd" ]);
        default_format_opts.lsp_format = "fallback";
        format_on_save.timeout_ms = 1500;
      };
    };
    lint = {
      enable = true;
      autoInstall.enable = true;
      lintersByFt.yaml = [ "yamllint" ];
      # Run on Kubernetes manifests only, see autoCmd.
      customLinters.kubeconform = {
        cmd = lib.getExe pkgs.kubeconform;
        stdin = true;
        args = [
          "-strict"
          "-ignore-missing-schemas"
          "-output"
          "json"
          "-"
        ];
        ignore_exitcode = true;
        # kubeconform reports no line numbers: findings land on line 1.
        parser = ''
          function(output)
            local ok, report = pcall(vim.json.decode, output, { luanil = { object = true, array = true } })
            local diagnostics = {}
            for _, res in ipairs(ok and report.resources or {}) do
              if res.status == "statusInvalid" or res.status == "statusError" then
                for _, err in ipairs(res.validationErrors or { { msg = res.msg } }) do
                  table.insert(diagnostics, {
                    lnum = 0,
                    col = 0,
                    severity = vim.diagnostic.severity.ERROR,
                    source = "kubeconform",
                    message = ("%s/%s: %s %s"):format(res.kind, res.name, err.path or "", err.msg),
                  })
                end
              end
            end
            return diagnostics
          end
        '';
      };
    };

    # Git, terminal, AI
    gitsigns.enable = true;
    diffview.enable = true;
    lazygit.enable = true;
    toggleterm = {
      enable = true;
      settings.size = 14;
    };
    claudecode = {
      enable = true;
      settings = {
        auto_start = false;
        terminal = {
          provider = "native";
          split_side = "right";
          split_width_percentage = 0.35;
        };
      };
    };
  };

  lsp = {
    inlayHints.enable = true;
    servers = {
      # Completes against `<nixpkgs>`; point `settings.nixd.options` at your
      # flake for option completion too (README).
      nixd.enable = true;
      yamlls = {
        enable = true;
        config.settings.yaml = {
          keyOrdering = false;
          format.enable = false; # prettierd formats
          schemaStore.enable = true;
        };
      };
      helm_ls.enable = true;
      jsonls.enable = true;
      lua_ls.enable = true;
      bashls.enable = true;
      dockerls.enable = true;
      taplo.enable = true;
      marksman.enable = true;
    };
    keymaps =
      lib.mapAttrsToList
        (key: lspBufAction: {
          inherit key lspBufAction;
        })
        {
          gd = "definition";
          gD = "declaration";
          gr = "references";
          gi = "implementation";
          gy = "type_definition";
          "<leader>cr" = "rename";
          "<leader>ca" = "code_action";
        };
  };

  dependencies.ripgrep.enable = true; # telescope live_grep, grug-far

  autoCmd = [
    {
      event = "TermOpen";
      command = "setlocal nobuflisted";
      desc = "Keep terminals out of barbar's file tabs";
    }
    {
      event = [
        "FocusGained"
        "BufEnter"
        "TermClose"
        "TermLeave"
      ];
      command = "if &buftype == '' && mode() != 'c' | checktime | endif";
      desc = "Reload files changed on disk";
    }
    {
      event = "FileType";
      pattern = [
        "markdown"
        "gitcommit"
        "gitrebase"
        "text"
      ];
      command = "setlocal spell";
      desc = "Spell-check prose";
    }
    {
      event = "VimEnter";
      nested = true;
      callback.__raw = ''
        function()
          if vim.fn.argc() == 0 and vim.env.ZELLIJ then
            require("persistence").load()
          end
        end
      '';
      desc = "Restore the session of an IDE opened on a project";
    }
    {
      event = "User";
      pattern = "PersistenceSavePre";
      command = "doautocmd User SessionSavePre";
      desc = "Let barbar save its tab order";
    }
    {
      event = [
        "FileType" # not BufReadPost, which runs before filetype detection
        "BufWritePost"
      ];
      callback.__raw = ''
        function(args)
          local head = "\n" .. table.concat(vim.api.nvim_buf_get_lines(args.buf, 0, 512, false), "\n")
          if vim.bo[args.buf].filetype == "yaml" and head:find("\napiVersion:%s*%S") and head:find("\nkind:%s*%S") then
            require("lint").try_lint("kubeconform")
          end
        end
      '';
      desc = "Validate Kubernetes manifests";
    }
  ];

  extraConfigLua = ''
    -- Messages in a float rather than hit-enter prompts (cmdheight=0).
    require("vim._core.ui2").enable({ msg = { targets = "msg" } })

    -- An editor window: one showing a file, not a terminal, a panel or a float.
    local function is_editor(win)
      return vim.api.nvim_win_get_config(win).relative == "" and vim.bo[vim.api.nvim_win_get_buf(win)].buftype == ""
    end

    -- Called by `revim open` right before `--remote`, whose `:drop` edits in
    -- the current window: move to an editor window, then take the zellij focus.
    function _G.RevimFocus()
      local wins = vim.api.nvim_tabpage_list_wins(0)
      table.insert(wins, 1, vim.api.nvim_get_current_win())
      for _, win in ipairs(wins) do
        if is_editor(win) then
          vim.api.nvim_set_current_win(win)
          break
        end
      end
      vim.system({ "zellij", "action", "focus-pane-id", vim.env.ZELLIJ_PANE_ID })
      return ""
    end

    -- Runs an Ex command, reporting its error as Neovim would.
    local function try(cmd)
      local ok, err = pcall(vim.cmd, cmd)
      if not ok then
        vim.api.nvim_echo({ { err:gsub("^.-Vim%b():", ""), "ErrorMsg" } }, true, { err = true })
      end
      return ok
    end

    -- :RevimClose[!] [{save}]: run {save} (`:write`, `:update`), then close the
    -- file (barbar's tab), asking first whether to save unsaved changes. The
    -- window stays, on another file or an empty one.
    vim.api.nvim_create_user_command("RevimClose", function(opts)
      if opts.args ~= "" and not try(opts.args) then
        return
      end
      local force = opts.bang
      if vim.bo.modified and not force then
        local name = vim.fn.expand("%:~:.")
        local choice = vim.fn.confirm(
          ('Save changes to "%s"?'):format(name ~= "" and name or "Untitled"),
          "&Yes\n&No\n&Cancel"
        )
        if choice == 2 then
          force = true
        elseif choice ~= 1 or not try("write") then
          return
        end
      end
      vim.cmd.BufferClose({ bang = force })
    end, { bang = true, nargs = "?", desc = "Close the file" })

    -- In the IDE (`revim nvim`), Neovim stays up next to yazi: in the last
    -- editor window, :q, :wq and :x close the file instead. :qa quits.
    if vim.g.revim_ide then
      for cmd, save in pairs({ q = "", wq = " write", x = " update" }) do
        vim.keymap.set("ca", cmd, function()
          local editors = vim.tbl_filter(is_editor, vim.api.nvim_tabpage_list_wins(0))
          local last = #vim.api.nvim_list_tabpages() == 1 and #editors == 1 and is_editor(0)
          return vim.fn.getcmdtype() == ":" and vim.fn.getcmdline() == cmd and last and "RevimClose" .. save or cmd
        end, { expr = true, desc = "Close the file, not Neovim" })
      end
    end

    -- sops: an encrypted YAML, JSON, dotenv or INI file opens decrypted, and
    -- saves through `sops edit`, which keeps its keys. Its plaintext stays out
    -- of swap and undo files, and out of the selection shared with Claude.
    local sops_markers = {
      yaml = "\nsops:",
      yml = "\nsops:",
      json = '"sops"%s*:',
      env = "\nsops_mac=",
      ini = "\n%[sops%]",
    }
    local sops_group = vim.api.nvim_create_augroup("revim_sops", {})

    -- Runs sops, its temporary files in Neovim's private temporary directory.
    -- Besides the age identities sops finds itself, the SSH key's, converted
    -- by ssh-to-age as sops-nix does (unless SOPS_AGE_KEY_CMD is set).
    local function sops(args, env)
      env = vim.tbl_extend("force", { TMPDIR = vim.fs.dirname(vim.fn.tempname()) }, env or {})
      local ssh_key = vim.env.SOPS_AGE_SSH_PRIVATE_KEY_FILE or vim.fs.normalize("~/.ssh/id_ed25519")
      if not vim.env.SOPS_AGE_KEY_CMD and vim.uv.fs_access(ssh_key, "R") then
        env.SOPS_AGE_KEY_CMD = "${lib.getExe pkgs.ssh-to-age} -private-key -i " .. vim.fn.shellescape(ssh_key)
      end
      return vim.system(vim.list_extend({ "${lib.getExe pkgs.sops}" }, args), { env = env, text = true }):wait()
    end

    local function sops_error(action, path, stderr)
      local reason = stderr:match('error="(.-)"\n') or stderr:match("[^\n]+") or ""
      vim.notify(("sops: cannot %s %s\n%s"):format(action, vim.fn.fnamemodify(path, ":~:."), reason), vim.log.levels.ERROR)
    end

    local function sops_save(buf)
      local path = vim.api.nvim_buf_get_name(buf)
      local plain = vim.fn.tempname()
      vim.fn.writefile(vim.api.nvim_buf_get_lines(buf, 0, -1, false), plain)
      -- `sops edit`'s editor moves the buffer's text over the decrypted file.
      -- On text sops rejects (invalid syntax…) it runs the editor again, which
      -- fails then: the file is left as it was.
      local editor = "${lib.getExe' pkgs.coreutils "mv"} -f -- " .. vim.fn.shellescape(plain)
      local res = sops({ "edit", path }, { SOPS_EDITOR = editor, EDITOR = editor })
      os.remove(plain)
      if res.code ~= 0 and res.code ~= 200 then -- 200: nothing changed
        return sops_error("save", path, res.stderr)
      end
      vim.bo[buf].modified = false
      vim.b[buf].revim_sops_stat = vim.uv.fs_stat(path)
      vim.api.nvim_echo({ { ('"%s" written (sops)'):format(vim.fn.fnamemodify(path, ":~:.")) } }, false, {})
    end

    local function sops_open(buf)
      vim.api.nvim_clear_autocmds({ group = sops_group, buffer = buf })
      vim.b[buf].revim_sops = nil
      local path = vim.api.nvim_buf_get_name(buf)
      local marker = sops_markers[path:match("%.(%w+)$")]
      local text = "\n" .. table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
      if not (marker and text:find(marker) and text:find("ENC%[AES256_GCM,")) then
        return
      end
      -- Before any plaintext: no swap file (this deletes it), no undo file.
      vim.bo[buf].swapfile = false
      vim.bo[buf].undofile = false
      local res = sops({ "decrypt", path })
      if res.code ~= 0 then
        return sops_error("decrypt", path, res.stderr)
      end
      local lines = vim.split(res.stdout, "\n")
      if lines[#lines] == "" then
        table.remove(lines)
      end
      -- No undoing back to the ciphertext.
      local undolevels = vim.bo[buf].undolevels
      vim.bo[buf].undolevels = -1
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
      vim.bo[buf].undolevels = undolevels
      vim.bo[buf].modified = false
      vim.b[buf].revim_sops = true
      vim.b[buf].revim_sops_stat = vim.uv.fs_stat(path)
      vim.api.nvim_create_autocmd("BufWriteCmd", {
        group = sops_group,
        buffer = buf,
        callback = function()
          sops_save(buf)
        end,
        desc = "Encrypt with sops",
      })
      vim.api.nvim_create_autocmd("FileChangedShell", {
        group = sops_group,
        buffer = buf,
        callback = function()
          -- Not when the change is sops encrypting this very buffer.
          local old, new = vim.b[buf].revim_sops_stat, vim.uv.fs_stat(path)
          local own = old and new and old.mtime.sec == new.mtime.sec and old.mtime.nsec == new.mtime.nsec and old.size == new.size
          vim.v.fcs_choice = own and "" or "ask"
        end,
        desc = "Keep the decrypted text over sops' own writes",
      })
    end

    vim.api.nvim_create_autocmd("BufReadPost", {
      group = sops_group,
      pattern = { "*.yaml", "*.yml", "*.json", "*.env", "*.ini" },
      callback = function(args)
        sops_open(args.buf)
      end,
      desc = "Decrypt sops files",
    })

    -- claudecode.nvim shares the selection with Claude: not a decrypted one.
    local selection = require("claudecode.selection")
    for _, fn in ipairs({ "update_selection", "flush_visual_selection" }) do
      local track = selection[fn]
      selection[fn] = function(...)
        if not vim.b.revim_sops then
          return track(...)
        end
      end
    end
  '';

  # VSCode-flavoured. Ctrl-Shift and Alt-Shift chords are best effort (Windows
  # Terminal does not deliver them); each has a <leader> or F-key twin.
  keymaps = [
    (bind "n" "<F1>" "<cmd>Telescope commands<cr>" "Command palette")
    (bind "n" "<C-S-p>" "<cmd>Telescope commands<cr>" "Command palette")
    (bind "n" "<C-p>" "<cmd>Telescope find_files<cr>" "Quick open")
    (bind [ "n" "i" "v" ] "<C-s>" "<cmd>w<cr>" "Save")
    (bind "n" "<C-a>" "ggVG" "Select all")
    (bind "v" "<C-c>" "\"+y" "Copy")
    (bind "v" "<C-x>" "\"+d" "Cut")
    (bind [ "i" "c" ] "<C-v>" "<C-r>+" "Paste")
    (bind "x" "<LeftRelease>" "\"+y" "Copy the mouse selection")
    (bind "n" "<A-Up>" "<cmd>m .-2<cr>==" "Move line up")
    (bind "n" "<A-Down>" "<cmd>m .+1<cr>==" "Move line down")
    (bind "i" "<A-Up>" "<esc><cmd>m .-2<cr>==gi" "Move line up")
    (bind "i" "<A-Down>" "<esc><cmd>m .+1<cr>==gi" "Move line down")
    (bind "v" "<A-Up>" ":m '<-2<cr>gv=gv" "Move selection up")
    (bind "v" "<A-Down>" ":m '>+1<cr>gv=gv" "Move selection down")
    (bind "n" "<A-S-Down>" "<cmd>t.<cr>" "Duplicate line")
    (bind "n" "<A-Left>" "<C-o>" "Back")
    (bind "n" "<A-Right>" "<C-i>" "Forward")
    (bind "n" "<Esc>" "<cmd>nohlsearch<cr>" "Clear search highlight")
    (bind "t" "<Esc>" "<C-\\><C-n>" "Leave terminal mode")

    # Code
    (bind "n" "<F2>" "<cmd>lua vim.lsp.buf.rename()<cr>" "Rename symbol")
    (bind "n" "<F12>" "<cmd>lua vim.lsp.buf.definition()<cr>" "Go to definition")
    (bind "n" "<S-F12>" "<cmd>Telescope lsp_references<cr>" "Find references")
    (bind "n" "<C-.>" "<cmd>lua vim.lsp.buf.code_action()<cr>" "Code action")
    (bind "n" "<F8>" "<cmd>lua vim.diagnostic.jump({ count = 1, float = true })<cr>" "Next problem")
    (bind "n" "<S-F8>" "<cmd>lua vim.diagnostic.jump({ count = -1, float = true })<cr>"
      "Previous problem"
    )
    (bind "n" "<leader>cd" "<cmd>lua vim.diagnostic.open_float()<cr>" "Line diagnostics")
    (bind "n" "<leader>ch" "<cmd>lua vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())<cr>"
      "Toggle inlay hints"
    )
    (bind "n" "<A-S-f>" "<cmd>lua require('conform').format({ async = true })<cr>" "Format")
    (bind "n" "<leader>cf" "<cmd>lua require('conform').format({ async = true })<cr>" "Format")
    (bind "n" "<leader>co" "<cmd>AerialToggle<cr>" "Outline")
    (bind "n" "<leader>cm" "<cmd>RenderMarkdown toggle<cr>" "Toggle markdown rendering")

    # Navigation
    (bind [ "n" "x" "o" ] "s" "<cmd>lua require('flash').jump()<cr>" "Flash")
    # Not in visual mode, where `S` is nvim-surround's.
    (bind [ "n" "o" ] "S" "<cmd>lua require('flash').treesitter()<cr>" "Flash treesitter")
    (bind "n" "<S-h>" "<cmd>BufferPrevious<cr>" "Previous file")
    (bind "n" "<S-l>" "<cmd>BufferNext<cr>" "Next file")
    (bind "n" "<C-Tab>" "<cmd>BufferNext<cr>" "Next file")
    # A terminal sends <C-i> as <Tab>: jump forward stays on <A-Right>.
    (bind "n" "<Tab>" "<cmd>BufferNext<cr>" "Next file")
    (bind "n" "<S-Tab>" "<cmd>BufferPrevious<cr>" "Previous file")
    (bind "n" "<leader>bd" "<cmd>RevimClose<cr>" "Close file")
    (bind "n" "<C-b>" focusFiles "Focus the file pane")
    (bind "n" "<leader>e" focusFiles "Focus the file pane")

    # Search & replace across the project
    (bind "n" "<C-S-f>" "<cmd>GrugFar<cr>" "Find & replace in files")
    (bind "n" "<leader>sr" "<cmd>GrugFar<cr>" "Find & replace in files")
    (bind "v" "<leader>sr" "<cmd>lua require('grug-far').with_visual_selection()<cr>"
      "Find & replace the selection"
    )
    (bind "n" "<leader>sw"
      "<cmd>lua require('grug-far').open({ prefills = { search = vim.fn.expand('<cword>') } })<cr>"
      "Find & replace the word"
    )

    # Git
    # Diff mode keeps its own ]c / [c.
    (hunk "]c" "&diff ? ']c' : '<cmd>Gitsigns nav_hunk next<cr>'" "Next hunk")
    (hunk "[c" "&diff ? '[c' : '<cmd>Gitsigns nav_hunk prev<cr>'" "Previous hunk")
    (bind "n" "<leader>gs" "<cmd>Gitsigns stage_hunk<cr>" "Stage hunk")
    (bind "v" "<leader>gs" ":Gitsigns stage_hunk<cr>" "Stage selection")
    (bind "n" "<leader>gr" "<cmd>Gitsigns reset_hunk<cr>" "Reset hunk")
    (bind "v" "<leader>gr" ":Gitsigns reset_hunk<cr>" "Reset selection")
    (bind "n" "<leader>gS" "<cmd>Gitsigns stage_buffer<cr>" "Stage file")
    (bind "n" "<leader>gp" "<cmd>Gitsigns preview_hunk<cr>" "Preview hunk")
    (bind "n" "<leader>gb" "<cmd>lua require('gitsigns').blame_line({ full = true })<cr>" "Blame line")
    (bind "n" "<leader>gd" "<cmd>Gitsigns diffthis<cr>" "Diff this")
    (bind "n" "<leader>gg" "<cmd>LazyGit<cr>" "Lazygit")
    (bind "n" "<leader>gv" "<cmd>DiffviewOpen<cr>" "Diff view")
    (bind "n" "<leader>gV" "<cmd>DiffviewClose<cr>" "Close diff view")
    (bind "n" "<leader>gh" "<cmd>DiffviewFileHistory %<cr>" "File history")
    (bind "n" "<leader>gH" "<cmd>DiffviewFileHistory<cr>" "Branch history")

    # Panels
    (bind "n" "<leader>xx" "<cmd>Trouble diagnostics toggle<cr>" "Problems")
    (bind "n" "<leader>xX" "<cmd>Trouble diagnostics toggle filter.buf=0<cr>" "Problems (file)")
    (bind "n" "<leader>xs" "<cmd>Trouble symbols toggle focus=false<cr>" "Symbols")
    (bind "n" "<leader>xr" "<cmd>Trouble lsp toggle focus=false win.position=right<cr>"
      "LSP definitions & references"
    )
    (bind "n" "<leader>xt" "<cmd>TodoTrouble<cr>" "TODOs")
    (bind "n" "<leader>xq" "<cmd>Trouble qflist toggle<cr>" "Quickfix list")
    (bind "n" "<leader>xl" "<cmd>Trouble loclist toggle<cr>" "Location list")
    (bind "n" "<leader>t" "<cmd>ToggleTerm<cr>" "Toggle terminal")
    (bind [ "n" "t" ] "<A-t>" "<cmd>TermNew<cr>" "New terminal")

    # Claude Code, Session
    (bind "n" "<leader>ac" "<cmd>ClaudeCode<cr>" "Toggle Claude")
    (bind "n" "<leader>af" "<cmd>ClaudeCodeFocus<cr>" "Focus Claude")
    (bind "v" "<leader>as" "<cmd>ClaudeCodeSend<cr>" "Send the selection to Claude")
    (bind "n" "<leader>ab" "<cmd>execute 'ClaudeCodeAdd' fnameescape(expand('%:p'))<cr>"
      "Add the file to Claude's context"
    )
    (bind "n" "<leader>aa" "<cmd>ClaudeCodeDiffAccept<cr>" "Accept Claude's diff")
    (bind "n" "<leader>ad" "<cmd>ClaudeCodeDiffDeny<cr>" "Reject Claude's diff")
    (bind "n" "<leader>qs" "<cmd>lua require('persistence').load()<cr>" "Restore session")
    (bind "n" "<leader>qd" "<cmd>lua require('persistence').stop()<cr>" "Stop saving the session")
  ]
  # Ctrl-h/j/k/l cross Neovim windows, then zellij panes past the edge.
  ++
    lib.mapAttrsToList
      (
        key: dir: bind "n" "<C-${key}>" "<cmd>ZellijNavigate${dir}<cr>" "Window or pane ${lib.toLower dir}"
      )
      {
        h = "Left";
        j = "Down";
        k = "Up";
        l = "Right";
      }
  # Ctrl-/ toggles comments; some terminals send it as Ctrl-_.
  ++
    lib.concatMap
      (key: [
        (remap "n" key "gcc" "Toggle comment")
        (remap "v" key "gc" "Toggle comment")
      ])
      [
        "<C-/>"
        "<C-_>"
      ];
}
