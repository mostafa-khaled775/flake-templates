{
  description = "Collection of flake templates";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    pre-commit-hooks.url = "github:cachix/git-hooks.nix";
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs =
    {
      self,
      nixpkgs,
      treefmt-nix,
      pre-commit-hooks,
      systems,
      ...
    }:
    let
      # Small tool to iterate over each systems
      eachSystem = f: nixpkgs.lib.genAttrs (import systems) (system: f nixpkgs.legacyPackages.${system});
      # Eval the treefmt modules from ./treefmt.nix
      treefmtEval = eachSystem (pkgs: treefmt-nix.lib.evalModule pkgs ./treefmt.nix);
    in
    {
      templates = rec {
        dev-flake = {
          path = ./dev-flake;
          description = "A general development flake";
        };
        default = dev-flake;
      };

      formatter = eachSystem (pkgs: treefmtEval.${pkgs.system}.config.build.wrapper);
      checks = eachSystem (pkgs: {
        formatting = treefmtEval.${pkgs.system}.config.build.check self;
        pre-commit-check = pre-commit-hooks.lib.${pkgs.system}.run {
          src = ./.;
          hooks = {
            treefmt.enable = true;
            treefmt.package = treefmtEval.${pkgs.system}.config.build.wrapper;
            deadnix.enable = true;
          };
        };
      });
      devShells = eachSystem (pkgs: {
        default = nixpkgs.legacyPackages.${pkgs.system}.mkShell {
          inherit (self.checks.${pkgs.system}.pre-commit-check) shellHook;
          buildInputs = self.checks.${pkgs.system}.pre-commit-check.enabledPackages;
        };
      });
    };
}
