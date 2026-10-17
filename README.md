# revim

Neovim configured with nixvim (every plugin, language server and formatter from
nixpkgs: no plugin manager, no Mason), and an IDE around it: **yazi** as the file
pane and Neovim side by side in a **zellij** tab, plus **lazygit** and Claude Code.

```
┌ files ┐┌──────── editor (nvim) ────────┐
│ yazi  ││ [file1] │ [file2] │ [file3] … │  ← barbar tabs
│       ││                               │
├───────┴┴────────── terminal ───────────┤
└────────────────────────────────────────┘
```

Each IDE tab runs its own Neovim server: picking a file in yazi or in a picker
opens it as a tab of the Neovim next to it.

## The package

`pkgs/revim/package.nix` is a regular `callPackage` function, added to nixpkgs by
the flake's `overlays.default` (composed with nixvim's overlay). It is built
against the host's nixpkgs, which must allow the unfree `barbar.nvim` and
`claude-code`, and tuned with `.override`:

```nix
pkgs.revim.override {
  flavor = "latte"; # Catppuccin flavor
  clipboard = "wl-copy"; # "osc52" (default), "pbcopy", "wl-copy" or null
  extraConfig.opts.relativenumber = true; # any nixvim module
}
```

It provides `nvim` (also as `vi` and `vim`) and `revim`:

| Command              | What it does                                                                   |
| -------------------- | ------------------------------------------------------------------------------ |
| `revim [dir]`        | The IDE on a directory: a new tab inside zellij, else a `revim-<dir>` session. |
| `revim file…`        | Edit, as `nvim file…`.                                                         |
| `revim git [dir]`    | lazygit in a tab of its own.                                                   |
| `revim grep [query]` | Live ripgrep search; Enter opens the match in the tab's Neovim.                |
| `revim find`         | Fuzzy file picker; Enter opens the file in the tab's Neovim.                   |

In the IDE: in yazi, Enter or a left click opens a file and enters a folder, a
right click goes up, and the path in the header is a breadcrumb — clicking one of
its folders goes there; `s` / `S` find a file / search
contents, `Alt-t` adds a shell to the terminal stack, `Alt-q` closes the tab.
`Ctrl` + arrows move to the pane in that direction, from any pane (`Ctrl-h/j/k/l`
also do in Neovim, crossing its own windows first). In Neovim, `Tab` / `Shift-Tab` go to the next / previous file, and `:q` (`:wq`, `:x`) closes the file rather than the editor, asking first
whether to save unsaved changes; `:qa` quits. Neovim has VSCode-style keys (`Ctrl-s`, `Ctrl-p`, `F12`, `Ctrl-/`…) and a which-key
menu on `<space>`.

[sops] files (YAML, JSON, dotenv, INI) open decrypted and save re-encrypted,
through `sops edit`: their keys stay those of the file, and text sops rejects
(invalid syntax…) leaves the file as it was. Their plaintext is kept out of
swap and undo files and out of the selection Claude sees. sops finds its age
identities as usual (`SOPS_AGE_KEY_FILE`, `~/.config/sops/age/keys.txt`…) plus,
unless `SOPS_AGE_KEY_CMD` is set, the SSH key `~/.ssh/id_ed25519` (or
`SOPS_AGE_SSH_PRIVATE_KEY_FILE`) converted by `ssh-to-age`, as sops-nix derives
identities.

[sops]: https://github.com/getsops/sops

## The Home Manager module

`homeModules.default` installs `pkgs.revim`, overridden from its options, and
configures what the IDE runs in: yazi (opening files in the tab's Neovim),
zellij (mouse, clipboard, keys) and lazygit.

The theme is the host's. When it sets a Catppuccin one with [catppuccin/nix]
(`catppuccin.enable`), Neovim takes its `catppuccin.flavor`, and yazi and lazygit
its ports (flavor and accent); without one, Neovim stays Catppuccin Mocha. The
zellij bars, bat and fzf are left to the host's own settings. revim does not
depend on catppuccin/nix.

| Option                        | Default   |                                                       |
| ----------------------------- | --------- | ----------------------------------------------------- |
| `programs.revim.enable`       | `false`   |                                                       |
| `programs.revim.package`      | `pkgs.revim` | From the overlay.                                  |
| `programs.revim.defaultEditor` | `false`  | `EDITOR` and `VISUAL` set to `nvim`.                  |
| `programs.revim.clipboard`    | `"osc52"` | Neovim's `g:clipboard` and zellij's `copy_command`.   |
| `programs.revim.extraConfig`  | `{ }`     | Extra nixvim configuration.                           |

[catppuccin/nix]: https://github.com/catppuccin/nix

## Use it

In a NixOS flake with Home Manager (as [NixOs-Config](https://github.com/pchesneau/NixOs-Config) does):

```nix
{
  inputs.revim = {
    url = "github:maximeq95/revim";
    inputs.nixpkgs.follows = "nixpkgs";
    inputs.home-manager.follows = "home-manager";
  };

  # in the NixOS configuration
  nixpkgs.overlays = [ inputs.revim.overlays.default ];
  home-manager.sharedModules = [ inputs.revim.homeModules.default ];

  # in a Home Manager configuration
  programs.revim = {
    enable = true;
    defaultEditor = true;
    clipboard = "wl-copy";
    # nixd completes the options of the host's flake
    extraConfig.lsp.servers.nixd.config.settings.nixd.options.nixos.expr =
      ''(builtins.getFlake "/etc/nixos").nixosConfigurations.nixos.options'';
  };
}
```

## Hack on it

```
nix run . -- file.txt  # try the editor
nix fmt                # nixfmt over the tree
nix flake check        # builds the Home Manager module for a throwaway user
```

| Path                               | What                                                     |
| ---------------------------------- | -------------------------------------------------------- |
| `pkgs/revim/package.nix`           | The package: Neovim and the `revim` command              |
| `pkgs/revim/nvim.nix`              | The nixvim module: plugins, language servers, keymaps    |
| `pkgs/revim/revim.sh`, `layout.kdl` | The `revim` command and its zellij layout               |
| `modules/home-manager/`            | The Home Manager module; yazi's mouse and header in `yazi.lua`, its `<Enter>` in `smart-enter.lua` |
