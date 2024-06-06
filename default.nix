{ lib, crystal, llvmPackages, openssl, makeWrapper }:
crystal.buildCrystalPackage {
  pname = "trackmap-cli";
  version = "0.1.0";
  src = ./.;

  format = "crystal";
  shardsFile = ./shards.nix;

  nativeBuildInputs = [ llvmPackages.llvm openssl makeWrapper ];

  doCheck = false;
  doInstallCheck = false;

  crystalBinaries.trackmap = {
    src = "src/trackmap-cli.cr";
    options = [ "--release" "--no-debug" "--progress" "-Dpreview_mt" ];
  };

  postInstall = ''
    wrapProgram "$out/bin/trackmap" --prefix PATH : '${
      lib.makeBinPath [llvmPackages.llvm.dev]
    }'
  '';

  meta = with lib; {
    description = "A tool for building maps for garmin gps devices";
    homepage = "https://github.com/repomaa/trackmap-cli";
    license = licenses.mit;
    maintainers = "Joakim Repomaa <nix@pimeys.pm>";
  };
}
