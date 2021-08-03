{ oracle-suite }:
{ pkgs, config, lib, ... }:
let
  writeJSON = name: attrs: pkgs.writeText name (builtins.toJSON attrs);

  cfg = config.services.omnia;
  ssbIncomingPorts = (if (cfg.ssbConfig ? connections) then
    (if (cfg.ssbConfig.connections ? incoming && cfg.ssbConfig.connections.incoming ? net) then
      map (x: if (x ? port) then x.port else 8008) cfg.ssbConfig.connections.incoming.net
    else
      [ 8008 ])
  else
    (if (cfg.ssbConfig ? port) then [ cfg.ssbConfig.port ] else [ 8008 ]));

  ssb-config = writeJSON "ssb-config" cfg.ssbConfig;
  omnia-config = writeJSON "omnia.conf" { inherit (cfg) pairs mode feeds ethereum options sources transports services; };

  inherit (import ../. { }) omnia ssb-server;

  name = "omnia";
  home = "/var/lib/${name}";
in {
  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [ ssb-server omnia ];

    networking.firewall.allowedTCPPorts = ssbIncomingPorts;

    systemd.services.gofer = {
      enable = true;
      description = "Gofer Agent";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" "omnia.service" ];

      serviceConfig = {
        Type = "simple";
        User = name;
        Group = name;
        PermissionsStartOnly = true;
        Restart = "always";
        RestartSec = 5;
        ExecStart = "${oracle-suite}/bin/gofer --config ${cfg.options.goferConfig} agent";
      };
    };

    systemd.services.spire = {
      enable = true;
      description = "Spire Agent";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" "omnia.service" ];

      serviceConfig = {
        Type = "simple";
        User = name;
        Group = name;
        PermissionsStartOnly = true;
        Restart = "always";
        RestartSec = 5;
        ExecStart = "${oracle-suite}/bin/spire --config ${cfg.options.spireConfig} --log.verbosity debug agent";
      };
    };

    systemd.services.ssb-server = {
      enable = true;
      description = "Scuttlebot server";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" "omnia.service" ];

      serviceConfig = {
        Type = "simple";
        User = name;
        Group = name;
        WorkingDirectory = home;
        PermissionsStartOnly = true;
        Restart = "always";
        RestartSec = 5;
        ExecStart = "${ssb-server}/bin/ssb-server start";
      };

      preStart = ''
        installSsbFile() {
          local from="$1"
          local target="${home}/.ssb/$2"
          if [[ ! -e "$target" ]]; then
            echo >&2 "SSB Service Setup: $target not found! Initiallizing with $from -> $target"
            cp -f "$from" "$target"
          else
            echo >&2 "SSB Service Setup: $target exists! Not overwriting"
          fi
        }

        mkdir -p "${home}/.ssb"
      '' + (lib.optionalString (cfg.ssbInitSecret != null) ''
        installSsbFile "${cfg.ssbInitSecret}" "secret"
      '') + (lib.optionalString (cfg.ssbInitGossip != null) ''
        installSsbFile "${cfg.ssbInitGossip}" "gossip.json"
      '') + ''
        ln -sf "${ssb-config}" "${home}/.ssb/config"
        chown -R ${name}:${name} "${home}/.ssb"
        chmod -R ug+w "${home}/.ssb"
      '';
    };

    systemd.services.omnia = {
      enable = true;
      description = "Omnia oracle client";
      after = [ "network.target" "ssb-server.service" ];
      wants = [ "ssb-server.service" ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        OMNIA_CONFIG = omnia-config;
        OMNIA_DEBUG = toString cfg.options.debug;
        OMNIA_LOG_FORMAT = cfg.options.logFormat;
        OMNIA_VERBOSE = toString cfg.options.verbose;
        GOFER_CONFIG = toString cfg.options.goferConfig;
        SPIRE_CONFIG = toString cfg.options.spireConfig;
      };

      serviceConfig = {
        Type = "simple";
        User = name;
        Group = name;
        WorkingDirectory = home;
        PermissionsStartOnly = true;
        Restart = "always";
        RestartSec = 5;
        ExecStart = "${omnia}/bin/omnia";
      };
    };

    users.groups."${name}" = { inherit name; };
    users.users."${name}" = {
      inherit name;
      group = name;
      home = home;
      createHome = true;
      shell = "${pkgs.bash}/bin/bash";
      isSystemUser = true;
    };
  };
}
