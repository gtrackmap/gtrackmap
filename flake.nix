{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    frontend.url = "github:gtrackmap/frontend";
  };
  outputs = { nixpkgs, flake-utils, frontend, self, ... }:
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          crystal = pkgs.crystal;
          llvmPackages = pkgs.llvmPackages;
          openssl = pkgs.openssl;
          makeWrapper = pkgs.makeWrapper;
          lib = pkgs.lib;
          frontendBuild = frontend.packages.${system}.default;
          trackmap = self.packages.${system}.default;
        in
        {
          nixosModules.default = { lib, config, ... }:
            let
              cfg = config.services.gtrackmap;
            in
            {
              options = {
                services.gtrackmap = {
                  enable = lib.mkEnableOption "Enable gtrackmap";
                  port = lib.mkOption {
                    type = lib.types.int;
                    default = 3000;
                    description = "Port to serve the webapp on";
                  };
                };
              };

              config = lib.mkIf cfg.enable {
                users = {
                  users.gtrackmap.isSystemUser = true;
                  groups.gtrackmap = { };
                };

                systemd.services.gtrackmap = {
                  wantedBy = [ "multi-user.target" ];
                  script = "${trackmap}/bin/gtrackmap";
                  environment = {
                    GTRACKMAP_PORT = toString cfg.port;
                  };
                  serviceConfig = {
                    User = config.users.users.gtrackmap.name;
                    Group = config.users.groups.gtrackmap.name;
                  };
                };
              };
            };
          packages.default = crystal.buildCrystalPackage {
            pname = "gtrackmap";
            version = "0.1.0";
            src = ./.;

            format = "crystal";
            shardsFile = ./shards.nix;

            buildInputs = [ frontendBuild ];
            nativeBuildInputs = [ llvmPackages.llvm openssl makeWrapper ];

            preBuild = ''
              cp -r ${frontendBuild} frontend
            '';

            doCheck = false;
            doInstallCheck = false;

            crystalBinaries.gtrackmap = {
              src = "src/gtrackmap.cr";
              options = [ "--release" "--no-debug" "--progress" "-Dpreview_mt" ];
            };

            postInstall = ''
              wrapProgram "$out/bin/gtrackmap" --prefix PATH : '${
                lib.makeBinPath [
                  llvmPackages.llvm.dev
                  pkgs.gpsbabel
                  pkgs.mkgmap
                ]
              }'
            '';

            meta = with lib; {
              description = "A nifty webapp for building maps around gpx tracks for garmin gps devices";
              homepage = "https://github.com/gtrackmap/gtrackmap";
              license = licenses.agpl3Plus;
              maintainers = [ "Joakim Repomaa <nix@pimeys.pm>" ];
            };
          };
        });
}
