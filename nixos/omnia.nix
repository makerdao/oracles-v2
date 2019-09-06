{ pkgs, config, lib, ... }: let
  inherit (builtins) toJSON fromJSON;
  inherit (pkgs) writeText bash;
  inherit (lib) mkIf;

  writeJSON = name: attrs: writeText name (toJSON attrs);

  cfg = config.services.omnia;
  name = "omnia";
  user = "omnia";

  ssb-config = writeJSON "ssb-config" cfg.ssbConfig;

  omnia-config = writeJSON "omnia.conf" {
    inherit (cfg) pairs mode;
    ethereum = { inherit (cfg) from keystore password; };
    options = { inherit (cfg) interval verbose; };
  };

  inherit (import ../. {
    inherit ssb-config;
    #inherit (import ../../nixpkgs-pin { dapptoolsOverrides = { current = ../../dapptools; }; }) pkgs;
  }) omnia ssb-server;
in {
  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      ssb-server
      omnia
    ];

    systemd.services.ssb-server = {
      enable = true;
      description = "Scuttlebot server";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = user;
        Group = user;
        WorkingDirectory = "/var/lib/${name}";
        PermissionsStartOnly = true;
        Restart = "always";
        RestartSec = 5;
        ExecStart = "${ssb-server}/bin/ssb-server start";
      };
    };

    systemd.services.omnia = {
      enable = true;
      description = "Omnia oracle client";
      after = [ "network.target" ];
      wants = [ "ssb-server.service" ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        OMNIA_CONFIG = omnia-config;
        OMNIA_DEBUG = toString cfg.debug;
      };

      serviceConfig = {
        Type = "simple";
        User = user;
        Group = user;
        WorkingDirectory = "/var/lib/${name}";
        PermissionsStartOnly = true;
        Restart = "always";
        RestartSec = 5;
        ExecStart = "${omnia}/bin/omnia";
      };
    };

    users.extraUsers = [
      {
        name = user;
        group = user;
        home = "/var/lib/${user}";
        createHome = true;
        shell = "${pkgs.bash}/bin/bash";
        isSystemUser = true;
      }
    ];

    users.extraGroups = [
      { name = "${user}"; }
    ];
  };
}
