{ self }:
{ lib, config, pkgs, ... }:
let
  trackmap = self.packages.${pkgs.system}.default;
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
      users.gtrackmap = {
        isSystemUser = true;
        group = config.users.groups.gtrackmap.name;
      };
      groups.gtrackmap = { };
    };

    systemd.services.gtrackmap = {
      wantedBy = [ "multi-user.target" ];
      environment = {
        GTRACKMAP_PORT = toString cfg.port;
      };
      serviceConfig = {
        User = config.users.users.gtrackmap.name;
        Group = config.users.groups.gtrackmap.name;
        ExecStart = "${trackmap}/bin/gtrackmap";
      };
    };
  };
}
