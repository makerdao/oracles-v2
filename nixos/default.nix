{ pkgs, config, lib, ... }: with lib; let
  defaultFeedConfig = lib.importJSON ../omnia/config/feed.conf;
in {
  options.services.omnia = {
    enable = mkEnableOption "omnia";

    mode = mkOption {
      type = types.enum [ "feed" "relayer" ];
      description = ''
        Omnia operational mode (feed or relayer)
      '';
      default = defaultFeedConfig.mode;
    };

    options = {
      verbose = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enable verbose output.
        '';
      };

      debug = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Enable debug output
        '';
      };

      interval = mkOption {
        type = types.int;
        description = ''
          Pooling interval
        '';
        default = defaultFeedConfig.options.interval;
      };

      msgLimit = mkOption {
        type = types.int;
        description = ''
          Message look back limit
        '';
        default = defaultFeedConfig.options.msgLimit;
      };

      srcTimeout = mkOption {
        type = types.int;
        description = ''
          Price source timeout
        '';
        default = defaultFeedConfig.options.srcTimeout;
      };

      setzerTimeout = mkOption {
        type = types.int;
        description = ''
          Setzer internal timeout
        '';
        default = defaultFeedConfig.options.setzerTimeout;
      };

      setzerCacheExpiry = mkOption {
        type = types.int;
        description = ''
          Setzer internal cache expiry
        '';
        default = defaultFeedConfig.options.setzerCacheExpiry;
      };

      setzerMinMedian = mkOption {
        type = types.int;
        description = ''
          Setzer internal minimum amount of sources for median
        '';
        default = defaultFeedConfig.options.setzerMinMedian;
      };

      goferConfig = mkOption {
        type = types.path;
        description = ''
          Path to Gofer config file.
        '';
        default = ../systemd/gofer.json;
      };
    };

    sources = mkOption {
      type = types.listOf (types.enum ["gofer" "setzer"]);
      description = ''
        List of sources to use and order they fallback in.
      '';
      default = defaultFeedConfig.sources;
    };

    transports = mkOption {
      type = types.listOf types.str;
      description = ''
        Transport CLIs to use.
      '';
      default = defaultFeedConfig.transports;
    };

    services = {

      scuttlebotIdMap = mkOption {
        type = with types; attrsOf str;
        description = ''
          Map of Ethereum addresses to Scuttlebot IDs.
        '';
        default = {};
      };
    };

    feeds = mkOption {
      type = types.listOf types.str;
      description = ''
        Scuttlebot feeds
      '';
      default = [];
    };

    pairs = mkOption {
      type = with types; attrsOf attrs;
      description = ''
        Trading pairs
      '';
      default = defaultFeedConfig.pairs;
    };

    ethereum = {
      from = mkOption {
        type = types.str;
        example = "0x0000000000000000000000000000000000000000";
        description = ''
          Ethereum address to use
        '';
      };

      keystore = mkOption {
        type = types.path;
        description = ''
          Ethereum keystore directory
        '';
      };

      password = mkOption {
        type = types.path;
        description = ''
          Ethereum private key password
        '';
      };

      network = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "http://localhost:8545";
        description = ''
          Ethereum network
        '';
      };
    };

    ssbConfig = mkOption {
      type = with types; attrs;
      description = ''
        Scuttlebot config
      '';
    };

    ssbInitSecret = mkOption {
      type = with types; nullOr path;
      description = ''
        Scuttlebot secret, if null will generate one
      '';
      default = null;
    };

    ssbInitGossip = mkOption {
      type = with types; nullOr path;
      description = ''
        gossip.json file to init scuttlebot with
      '';
      default = null;
    };
  };

  imports = [ ./omnia.nix ];
}
