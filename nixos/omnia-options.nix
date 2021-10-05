{ lib, pkgs }:
let
  writeJSON = name: attrs: pkgs.writeText name (builtins.toJSON attrs);
  passJSON = name: file: writeJSON name (lib.importJSON file);
in {
  enable = lib.mkEnableOption "omnia";

  mode = lib.mkOption {
    type = lib.types.enum [ "feed" "relay" "relayer" ];
    description = ''
      Omnia operational mode (feed or relay)
    '';
    default = "feed";
  };

  options = {
    logFormat = lib.mkOption {
      type = lib.types.str;
      default = "text";
    };

    verbose = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Enable verbose output.
      '';
    };

    debug = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable debug output
      '';
    };

    interval = lib.mkOption {
      type = lib.types.int;
      description = ''
        Pooling interval
      '';
      default = 60;
    };

    msgLimit = lib.mkOption {
      type = lib.types.int;
      description = ''
        Message look back limit
      '';
      default = 35;
    };

    srcTimeout = lib.mkOption {
      type = lib.types.int;
      description = ''
        Price source timeout
      '';
      default = 600;
    };

    setzerTimeout = lib.mkOption {
      type = lib.types.int;
      description = ''
        Setzer internal timeout
      '';
      default = 600;
    };

    setzerCacheExpiry = lib.mkOption {
      type = lib.types.int;
      description = ''
        Setzer internal cache expiry
      '';
      default = 120;
    };

    setzerMinMedian = lib.mkOption {
      type = lib.types.int;
      description = ''
        Setzer internal minimum amount of sources for median
      '';
      default = 3;
    };

    setzerEthRpcUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:9989";
    };

    goferConfig = lib.mkOption {
      type = lib.types.path;
      description = ''
        Path to Gofer config file.
      '';
      default = passJSON "gofer.json" ../systemd/gofer.json;
    };

    spireConfig = lib.mkOption {
      type = lib.types.path;
      description = ''
        Path to Spire config file.
      '';
      default = passJSON "spire.json" ../systemd/spire.json;
    };
  };

  sources = lib.mkOption {
    type = lib.types.listOf (lib.types.enum [ "gofer" "setzer" ]);
    description = ''
      List of sources to use and order they fallback in.
    '';
    default = [ "gofer" "setzer" ];
  };

  transports = lib.mkOption {
    type = lib.types.listOf (lib.types.enum [ "transport-spire" "transport-ssb" ]);
    description = ''
      Transport CLIs to use.
    '';
    default = [ "transport-spire" "transport-ssb" ];
  };

  ethRpcList = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
  };

  services = {
    scuttlebotIdMap = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      description = ''
        Map of Ethereum addresses to Scuttlebot IDs.
      '';
      default = { };
    };
  };

  feeds = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    description = ''
      Scuttlebot feeds
    '';
    default = [ ];
  };

  pairs = lib.mkOption {
    type = lib.types.attrsOf lib.types.attrs;
    description = ''
      Trading pairs
    '';
    default = [ ];
  };

  ethereum = {
    from = lib.mkOption {
      type = lib.types.str;
      example = "0x0000000000000000000000000000000000000000";
      description = ''
        Ethereum address to use
      '';
    };

    keystore = lib.mkOption {
      type = lib.types.path;
      description = ''
        Ethereum keystore directory
      '';
    };

    password = lib.mkOption {
      type = lib.types.path;
      description = ''
        Ethereum private key password
      '';
    };

    network = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "http://localhost:8545";
      description = ''
        Ethereum network
      '';
    };

    gasPrice = lib.mkOption {
      type = lib.types.attrs;
      default = {
        source = "node";
        multiplier = 1;
        priority = "fast";
      };
    };

  };

  ssbConfig = lib.mkOption {
    type = lib.types.attrs;
    description = ''
      Scuttlebot config
    '';
  };

  ssbInitSecret = lib.mkOption {
    type = lib.types.nullOr lib.types.path;
    description = ''
      Scuttlebot secret, if null will generate one
    '';
    default = null;
  };

  ssbInitGossip = lib.mkOption {
    type = lib.types.nullOr lib.types.path;
    description = ''
      gossip.json file to init scuttlebot with
    '';
    default = null;
  };
}
