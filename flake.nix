{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    frontend.url = "github:gtrackmap/frontend";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };
  outputs = { flake-parts, frontend, nixpkgs, ... }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } ({ flake-parts-lib, self, moduleWithSystem, ... }:
      let
        inherit (flake-parts-lib) importApply;
        package = importApply ./flake-module.nix { inherit frontend; };
        module = importApply ./nixos-module.nix { inherit self; };
      in
      {
        imports = [ package ];
        flake.nixosModules.default = module;
        systems = nixpkgs.legacyPackages.x86_64-linux.lib.systems.flakeExposed;
      }
    );
}
