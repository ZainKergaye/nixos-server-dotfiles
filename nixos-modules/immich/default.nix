{
  config,
  lib,
  ...
}:
let
  cfg = config.immich;
in
{
  options.immich = with lib; {
    enable = mkEnableOption "an authenticated Immich service with Borg backups";

    lanCidr = mkOption {
      type = types.str;
      default = "10.10.10.0/24";
      description = "LAN subnet permitted to access Immich";
    };

    wireGuardCidr = mkOption {
      type = types.str;
      default = "10.100.0.0/24";
      description = "WireGuard client subnet permitted to access Immich";
    };

    backup = {
      enable = mkEnableOption "daily Borg backups of the Immich data directory" // {
        default = true;
      };

      nfsServer = mkOption {
        type = types.str;
        default = "10.10.10.12";
        description = "NFSv4 server hosting the Borg repository";
      };

      nfsExport = mkOption {
        type = types.str;
        default = "/srv/backups/immich";
        description = "NFSv4 export containing the Immich Borg repository";
      };

      mountPoint = mkOption {
        type = types.str;
        default = "/mnt/immich-backup";
        description = "Local mount point for the NFSv4 backup export";
      };

      borgEncryptionMode = mkOption {
        type = types.enum [ "repokey" "keyfile" "repokey-blake2" "keyfile-blake2" "authenticated" "authenticated-blake2" "none" ];
        default = "none";
        description = "Borg repository encryption mode; use a pass command for encrypted modes";
      };

      borgPassCommand = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Command that prints the Borg passphrase without storing it in the Nix store";
      };
    };

    metrics.enable = mkEnableOption "Immich Prometheus metrics" // {
      default = true;
    };

    metrics.target = mkOption {
      type = types.str;
      default = "10.10.10.11";
      description = "Address of the Immich host scraped by the central Prometheus server";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      # Immich requires an account by default; this module deliberately does
      # not disable the upstream authentication flow.
      services.immich = {
        enable = true;
        host = "0.0.0.0";
        port = 2283;
        openFirewall = false;
        environment = {
          IMMICH_LOG_LEVEL = "warn";
          IMMICH_TELEMETRY_INCLUDE = "all";
          IMMICH_API_METRICS_PORT = "8081";
          IMMICH_MICROSERVICES_METRICS_PORT = "8082";
        };
      };

      networking.firewall.extraCommands = lib.mkAfter ''
        iptables -A nixos-fw -p tcp --dport 2283 -s ${cfg.lanCidr} -j ACCEPT
        iptables -A nixos-fw -p tcp --dport 2283 -s ${cfg.wireGuardCidr} -j ACCEPT
      '';
    })

    (lib.mkIf (cfg.enable && cfg.metrics.enable) {
      # Immich provides a separate endpoint for its API and microservices.
      # Prometheus runs only on main, so neither endpoint is LAN-public.
      networking.firewall.extraCommands = lib.mkAfter ''
        iptables -A nixos-fw -p tcp --dport 8081 -s ${config.prometheus.collectorAddress} -j ACCEPT
        iptables -A nixos-fw -p tcp --dport 8082 -s ${config.prometheus.collectorAddress} -j ACCEPT
      '';
    })

    # The central collector is configured on main, while Immich itself runs
    # on node1.  Keep the target and its scrape jobs with the service they
    # monitor rather than making the generic Prometheus module know about it.
    (lib.mkIf (cfg.metrics.enable && config.prometheus.server.enable) {
      services.prometheus.scrapeConfigs = [
        {
          job_name = "immich-api";
          static_configs = [
            {
              targets = [ "${cfg.metrics.target}:8081" ];
              labels.host = "node1";
            }
          ];
        }
        {
          job_name = "immich-microservices";
          static_configs = [
            {
              targets = [ "${cfg.metrics.target}:8082" ];
              labels.host = "node1";
            }
          ];
        }
      ];

      grafana.dashboards."immich.json" = lib.mkIf config.grafana.enable ./dashboard.json;
    })

    (lib.mkIf cfg.backup.enable {
      boot.supportedFilesystems = [ "nfs" ];
      fileSystems.${cfg.backup.mountPoint} = {
        device = "${cfg.backup.nfsServer}:${cfg.backup.nfsExport}";
        fsType = "nfs4";
        options = [ "_netdev" "noatime" "x-systemd.automount" "x-systemd.idle-timeout=300" ];
      };

      services.borgbackup.jobs.immich = {
        paths = [ config.services.immich.mediaLocation ];
        repo = "${cfg.backup.mountPoint}/borg";
        doInit = true;
        compression = "zstd,6";
        startAt = "*-*-* 03:30:00";
        persistentTimer = true;
        encryption = {
          mode = cfg.backup.borgEncryptionMode;
          passCommand = cfg.backup.borgPassCommand;
        };
        prune.keep = {
          daily = 7;
          weekly = 4;
          monthly = 12;
        };
      };

      assertions = [
        {
          assertion = cfg.backup.borgEncryptionMode == "none" || cfg.backup.borgPassCommand != null;
          message = "immich.backup.borgPassCommand must be set when Borg encryption is enabled";
        }
      ];
    })
  ];
}
