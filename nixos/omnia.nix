{ pkgs, config, lib, ... }: let
  inherit (builtins) toJSON fromJSON;
  inherit (pkgs) writeText bash;
  inherit (lib) mkIf optionalString;

  writeJSON = name: attrs: writeText name (toJSON attrs);

  cfg = config.services.omnia;
  ssbIncomingPorts = (
    if (cfg.ssbConfig ? connections)
    then (
      if (cfg.ssbConfig.connections ? incoming
        && cfg.ssbConfig.connections.incoming ? net)
      then map
        (x: if (x ? port) then x.port else 8008)
        cfg.ssbConfig.connections.incoming.net
      else [8008]
    )
    else (
      if (cfg.ssbConfig ? port)
      then [cfg.ssbConfig.port]
      else [8008]
    )
  );

  ssb-config = writeJSON "ssb-config" cfg.ssbConfig;
  omnia-config = writeJSON "omnia.conf" {
    inherit (cfg) pairs mode feeds ethereum options;
  };

  inherit (import ../. {
    inherit ssb-config;
    #inherit (import ../../nixpkgs-pin { dapptoolsOverrides = { current = ../../dapptools; }; }) pkgs;
  }) omnia ssb-server;

  name = "omnia";
  home = "/var/lib/${name}";
in {
  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      ssb-server
      omnia
    ];

    networking.firewall.allowedTCPPorts = ssbIncomingPorts;

    systemd.services.ssb-server = {
      enable = true;
      description = "Scuttlebot server";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

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
          installFile() {
            local from="$1"
            local target="$2"
            local targetDir="''${target%/*}"
            if [[ ! -e "$target" ]]; then
              echo >&2 "SSB Service Setup: $target not found! Initiallizing with $from -> $target"
              mkdir -p "$targetDir"
              chown ${name}:${name} "$targetDir"
              cp -f "$from" "$target"
              chown ${name}:${name} "$target"
              chmod ug+w "$target"
            else
              echo >&2 "SSB Service Setup: $target exists! Not overwriting"
            fi
          }
        ''
        + (optionalString (cfg.ssbInitSecret != null) ''
          installFile "${cfg.ssbInitSecret}" "${home}/.ssb/secret"
        '')
        + (optionalString (cfg.ssbInitGossip != null) ''
          installFile "${cfg.ssbInitGossip}" "${home}/.ssb/gossip.json"
        '');
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

    users.extraUsers = [
      {
        name = name;
        group = name;
        home = home;
        createHome = true;
        shell = "${pkgs.bash}/bin/bash";
        isSystemUser = true;
      }
    ];

    users.extraGroups = [
      { name = name; }
    ];
  };
}
