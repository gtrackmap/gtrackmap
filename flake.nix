{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    frontend.url = "github:gtrackmap/frontend";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };
  outputs = { self, flake-parts, ... }@inputs:
    flake-parts.lib.mkFlake { inherit inputs self; } {
      systems = [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ];
      imports = [
        ./package.nix
        ./nixos-module.nix
      ];
    };
}
