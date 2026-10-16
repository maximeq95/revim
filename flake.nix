{
  description = "revim — Neovim (nixvim), and an IDE around it: yazi and Neovim side by side in zellij";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Only used by `checks`.
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      nixvim,
      home-manager,
    }:
    {
      # `pkgs.revim`, built against the host's nixpkgs (which must allow the
      # unfree barbar.nvim and claude-code).
      overlays.default = nixpkgs.lib.composeManyExtensions [
        nixvim.overlays.default
        (final: prev: { revim = final.callPackage ./pkgs/revim/package.nix { }; })
      ];

      homeModules.default = ./modules/home-manager;
    }
    // flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ self.overlays.default ];
          config.allowUnfreePredicate =
            pkg:
            builtins.elem (nixpkgs.lib.getName pkg) [
              "barbar.nvim"
              "claude-code"
            ];
        };
      in
      {
        packages = {
          inherit (pkgs) revim;
          default = pkgs.revim;
        };

        formatter = pkgs.nixfmt-tree;

        # The Home Manager module, for a throwaway user.
        checks.default =
          (home-manager.lib.homeManagerConfiguration {
            inherit pkgs;
            modules = [
              self.homeModules.default
              {
                home = {
                  username = "revim";
                  homeDirectory = "/home/revim";
                  stateVersion = "26.05";
                };
                programs.revim = {
                  enable = true;
                  defaultEditor = true;
                };
              }
            ];
          }).activationPackage;
      }
    );
}
