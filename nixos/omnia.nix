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
    inherit (cfg) pairs mode feeds ethereum options services;
  };

  inherit (import ../. {}) omnia ssb-server;

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
        ''
        + (optionalString (cfg.ssbInitSecret != null) ''
          installSsbFile "${cfg.ssbInitSecret}" "secret"
        '')
        + (optionalString (cfg.ssbInitGossip != null) ''
          installSsbFile "${cfg.ssbInitGossip}" "gossip.json"
        '')
        + ''
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
