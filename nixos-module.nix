{ moduleWithSystem, ... }: {
  flake.nixosModules.default = moduleWithSystem (
    perSystem@{ config }:
    { lib, config, ... }:
    let
      package = perSystem.config.packages.default;
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
        systemd.services.gtrackmap = {
          wantedBy = [ "multi-user.target" ];
          environment = {
            GTRACKMAP_PORT = toString cfg.port;
          };
          serviceConfig = {
            ExecStart = "${package}/bin/gtrackmap";
            DynamicUser = true;
          };
          confinement.enable = true;
        };
      };
    }
  );
}
