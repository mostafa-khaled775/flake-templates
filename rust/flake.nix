{
  description = "Development flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    pre-commit-hooks.url = "github:cachix/git-hooks.nix";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    naersk.url = "github:nix-community/naersk/master";
    utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      pre-commit-hooks,
      treefmt-nix,
      naersk,
      utils,
      ...
    }:
    utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        # Eval the treefmt modules from ./treefmt.nix
        treefmtEval = treefmt-nix.lib.evalModule pkgs ./treefmt.nix;
        naersk-lib = pkgs.callPackage naersk { };
      in
      {
        defaultPackage = naersk-lib.buildPackage ./.;
        formatter = treefmtEval.${system}.config.build.wrapper;
        checks = {
          formatting = treefmtEval.${system}.config.build.check self;
          pre-commit-check = pre-commit-hooks.lib.${system}.run {
            src = ./.;
            hooks = {
              treefmt.enable = true;
              treefmt.package = treefmtEval.${system}.config.build.wrapper;
              deadnix.enable = true;
              clippy.enable = true;
            };
          };
        };
        devShells = {
          default = nixpkgs.legacyPackages.${system}.mkShell {
            inherit (self.checks.${system}.pre-commit-check) shellHook;
            RUST_SRC_PATH = pkgs.rustPlatform.rustLibSrc;
            buildInputs =
              with pkgs;
              [
                cargo
                rustc
                rustfmt
                rustPackages.clippy
              ]
              ++ self.checks.${system}.pre-commit-check.enabledPackages;
          };
        };
      }
    );
}
