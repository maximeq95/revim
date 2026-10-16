# Home Manager module: installs `pkgs.revim` (from this flake's overlay),
# overridden with the options below, and sets up what the IDE runs in: zellij,
# yazi and lazygit. The theme is the host's: when it sets a Catppuccin one
# (catppuccin/nix), Neovim takes its flavor and yazi and lazygit their port.
{
  config,
  lib,
  options,
  pkgs,
  ...
}:
let
  cfg = config.programs.revim;
  catppuccin = options ? catppuccin && config.catppuccin.enable;
in
{
  options.programs.revim = {
    enable = lib.mkEnableOption "revim, Neovim and a yazi + zellij IDE around it";

    package = lib.mkPackageOption pkgs "revim" {
      extraDescription = "Added to `pkgs` by revim's `overlays.default`.";
    };

    finalPackage = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      description = "`package`, overridden with the options of this module.";
    };

    defaultEditor = lib.mkEnableOption "revim's Neovim as the default editor (`EDITOR`, `VISUAL`)";

    clipboard = lib.mkOption {
      type =
        with lib.types;
        nullOr (enum [
          "osc52"
          "pbcopy"
          "wl-copy"
        ]);
      default = "osc52";
      example = "wl-copy";
      description = ''
        System clipboard tool for Neovim (`g:clipboard`) and zellij (`copy_command`):
        `"wl-copy"` on Wayland (WSLg included), `"pbcopy"` on macOS, `"osc52"`
        (terminal escapes) headless or over SSH, `null` for Neovim's autodetection.
      '';
    };

    extraConfig = lib.mkOption {
      type = lib.types.deferredModule;
      default = { };
      example = {
        lsp.servers.nixd.config.settings.nixd.options.nixos.expr =
          ''(builtins.getFlake "/etc/nixos").nixosConfigurations.nixos.options'';
      };
      description = "Extra nixvim configuration for revim's Neovim.";
    };
  };

  config = lib.mkIf cfg.enable (
    {
      programs.revim.finalPackage = cfg.package.override (
        {
          inherit (cfg) clipboard extraConfig;
          yazi = config.programs.yazi.finalPackage;
          zellij = config.programs.zellij.finalPackage;
        }
        // lib.optionalAttrs catppuccin { inherit (config.catppuccin) flavor; }
      );

      home.packages = [ cfg.finalPackage ];
      home.sessionVariables = lib.mkIf cfg.defaultEditor {
        EDITOR = "nvim";
        VISUAL = "nvim";
      };

      programs = {
        lazygit.enable = true;
        zsh.setOptions = [ "NO_FLOW_CONTROL" ]; # Ctrl-S saves in Neovim, it never freezes a shell

        # The file pane: a one-column tree whose picks open in the tab's Neovim.
        yazi = {
          enable = true;
          settings = {
            mgr = {
              ratio = [
                0
                1
                0
              ];
              show_hidden = true;
              sort_dir_first = true;
            };
            # `%s` is substituted by yazi itself: the file never reaches the shell as `$1`.
            opener.edit = [
              {
                run = "revim open %s";
                desc = "Open in the editor";
                block = false;
              }
            ];
            open.prepend_rules = [
              {
                url = "*";
                use = "edit";
              }
            ];
          };
          keymap.mgr.prepend_keymap = [
            {
              on = "s";
              run = "shell 'revim find' --block";
              desc = "Find a file (fd) and edit it";
            }
            {
              on = "S";
              run = "shell 'revim grep' --block";
              desc = "Search contents (rg) and edit the match";
            }
          ];
          initLua = ./yazi.lua;
        };

        zellij = {
          enable = true;
          # Selecting text copies it, through `copy_command` or else OSC 52.
          settings = lib.mapAttrs (_: lib.mkDefault) (
            {
              mouse_mode = true;
              focus_follows_mouse = true;
              mouse_click_through = true;
              copy_on_select = true;
            }
            // lib.optionalAttrs (cfg.clipboard == "wl-copy") {
              copy_command = lib.getExe' pkgs.wl-clipboard "wl-copy";
            }
            // lib.optionalAttrs (cfg.clipboard == "pbcopy") { copy_command = "pbcopy"; }
          );
          extraConfig = ''
            keybinds {
                normal {
                    // Leave to Neovim: save, quick open / completion, window navigation.
                    unbind "Ctrl s" "Ctrl p" "Ctrl n" "Ctrl h"
                }
                // In every mode, `locked` included, which a host may rest in.
                shared {
                    // A new shell in the terminal stack, under yazi and the editor.
                    bind "Alt t" { MoveFocus "Down"; NewPane "stacked"; }
                    bind "Alt q" { CloseTab; }
                    // Ctrl-arrows move to the pane in that direction, from any pane.
                    bind "Ctrl Left" { MoveFocus "Left"; }
                    bind "Ctrl Right" { MoveFocus "Right"; }
                    bind "Ctrl Up" { MoveFocus "Up"; }
                    bind "Ctrl Down" { MoveFocus "Down"; }
                }
            }
          '';
        };
      };
    }
    # Only when the host imports catppuccin/nix: `catppuccin` does not exist otherwise.
    // lib.optionalAttrs (options ? catppuccin) {
      catppuccin = lib.mkIf catppuccin {
        yazi.enable = lib.mkDefault true;
        lazygit.enable = lib.mkDefault true;
      };
    }
  );
}
