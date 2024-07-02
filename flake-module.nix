{ frontend }:
{ ... }:
{
  perSystem = { system, pkgs, lib, ... }:
    let
      frontendBuild = frontend.packages.${system}.default;
      inherit (pkgs) crystal openssl llvmPackages makeWrapper;
    in
    {
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
    };
}
