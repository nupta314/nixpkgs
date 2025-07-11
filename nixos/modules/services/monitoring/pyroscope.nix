{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    escapeShellArgs
    mkEnableOption
    mkPackageOption
    mkIf
    mkOption
    types
    ;

  cfg = config.services.pyroscope;

  settingsFormat = pkgs.formats.yaml { };
in
{
  options.services.pyroscope = {
    enable = mkEnableOption "pyroscope";

    configuration = mkOption {
      type = (pkgs.formats.json { }).type;
      default = { };
      description = ''
        Specify the configuration for Pyroscope in Nix.
      '';
    };

    configFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        Specify a configuration file that Pyroscope should use.
      '';
    };

    package = mkPackageOption pkgs "pyroscope" { };

    extraFlags = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "--config.expand-env=true" ];
      description = ''
        Specify a list of additional command line flags,
        which get escaped and are then passed to Pyroscope.
      '';
    };
  };

  config = mkIf cfg.enable {
    # for profilecli
    environment.systemPackages = [ cfg.package ];

    assertions = [
      {
        assertion = (
          (cfg.configuration == { } -> cfg.configFile != null)
          && (cfg.configFile != null -> cfg.configuration == { })
        );
        message = ''
          Please specify either
          'services.pyroscope.configuration' or
          'services.pyroscope.configFile'.
        '';
      }
    ];

    systemd.services.pyroscope = {
      description = "Pyroscope Service Daemon";
      requires = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig =
        let
          conf =
            if cfg.configFile == null then
              settingsFormat.generate "config.yaml" cfg.configuration
            else
              cfg.configFile;
        in
        {
          ExecStart = "${cfg.package}/bin/pyroscope --config.file=${conf} ${escapeShellArgs cfg.extraFlags}";
          DynamicUser = true;
          Restart = "always";
          ProtectSystem = "full";
          DevicePolicy = "closed";
          NoNewPrivileges = true;
          WorkingDirectory = "/var/lib/pyroscope";
          StateDirectory = "pyroscope";
        };
    };
  };
}
