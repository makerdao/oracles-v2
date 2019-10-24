{ pkgs, config, lib, ... }: with lib; {
  options.services.omnia = {
    enable = mkEnableOption "omnia";

    mode = mkOption {
      type = types.str;
      description = ''
        Omnia operational mode (feed or relayer)
      '';
      default = "feed";
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
        default = 60;
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
      default = {
        "BATUSD" = {
          "msgExpiration" = 1800;
          "msgSpread" = 0.5;
        };
        "BTCUSD" = {
          "msgExpiration" = 1800;
          "msgSpread" = 0.5;
        };
        "DGDUSD" = {
          "msgExpiration" = 1800;
          "msgSpread" = 0.5;
        };
        "ETHUSD" = {
          "msgExpiration" = 1800;
          "msgSpread" = 0.5;
        };
        "GNTUSD" = {
          "msgExpiration" = 1800;
          "msgSpread" = 0.5;
        };
        "MKRUSD" = {
          "msgExpiration" = 1800;
          "msgSpread" = 0.5;
        };
        "OMGUSD" = {
          "msgExpiration" = 1800;
          "msgSpread" = 0.5;
        };
        "REPUSD" = {
          "msgExpiration" = 1800;
          "msgSpread" = 0.5;
        };
        "ZRXUSD" = {
          "msgExpiration" = 1800;
          "msgSpread" = 0.5;
        };
      };
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
