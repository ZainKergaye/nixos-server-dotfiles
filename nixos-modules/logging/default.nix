{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.centralLogging;
  allowedAddresses = lib.unique (builtins.attrValues config.router.lanHosts);
in
{
  options.centralLogging = with lib; {
    enable = mkEnableOption "journal and container log shipping to the homelab Loki server";
    collectorAddress = mkOption {
      type = types.str;
      default = "10.10.10.1";
      description = "LAN address of the central log collector";
    };
    server.enable = mkEnableOption "the central Loki store and Grafana log dashboard";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      # NixOS OCI containers use the journald log driver, so their stdout and
      # stderr are collected without granting Vector access to Docker's socket.
      services.journald.settings.Journal = {
        Storage = "persistent";
        SystemMaxUse = lib.mkDefault "1G";
        MaxRetentionSec = lib.mkDefault "30day";
      };

      services.vector = {
        enable = true;
        journaldAccess = true;
        settings = {
          data_dir = "/var/lib/vector";
          sources.host_journal = {
            type = "journald";
            journalctl_path = "${pkgs.systemd}/bin/journalctl";
            current_boot_only = false;
            # Start with new logs on first deployment; subsequent starts resume
            # the durable cursor, including entries from a previous boot.
            since_now = true;
            acknowledgements.enabled = true;
            # Do not feed Loki connection errors back into the same pipeline.
            exclude_units = [ "vector.service" ];
          };
          transforms.normalize_journal = {
            type = "remap";
            inputs = [ "host_journal" ];
            source = builtins.readFile ./normalize-journal.vrl;
          };
          sinks.host_logs = {
            type = "loki";
            inputs = [ "normalize_journal" ];
            endpoint = if cfg.server.enable then
              "http://127.0.0.1:3100"
            else
              "http://${cfg.collectorAddress}:3101";
            # A collector outage must not prevent the agent from starting.
            healthcheck.enabled = false;
            encoding.codec = "json";
            labels = {
              job = "host-logs";
              host = config.networking.hostName;
              source = "{{ source }}";
              service_name = "{{ service_name }}";
              level = "{{ level }}";
            };
            buffer = {
              type = "disk";
              max_size = 536870912;
              when_full = "block";
            };
          };
        };
      };
    })

    (lib.mkIf cfg.server.enable {
      services.loki = {
        enable = true;
        configuration = {
          auth_enabled = false;
          server = {
            http_listen_address = "127.0.0.1";
            http_listen_port = 3100;
            grpc_listen_address = "127.0.0.1";
          };
          common = {
            path_prefix = "/var/lib/loki";
            instance_addr = "127.0.0.1";
            replication_factor = 1;
            ring.kvstore.store = "inmemory";
            storage.filesystem.chunks_directory = "/var/lib/loki/chunks";
          };
          schema_config.configs = [
            {
              from = "2024-01-01";
              store = "tsdb";
              object_store = "filesystem";
              schema = "v13";
              index = {
                prefix = "index_";
                period = "24h";
              };
            }
          ];
          storage_config.tsdb_shipper = {
            active_index_directory = "/var/lib/loki/tsdb-index";
            cache_location = "/var/lib/loki/tsdb-cache";
          };
          compactor = {
            working_directory = "/var/lib/loki/compactor";
            retention_enabled = true;
            delete_request_store = "filesystem";
          };
          ruler = {
            rule_path = "/var/lib/loki/rules-tmp";
            storage = {
              type = "local";
              local.directory = "/var/lib/loki/rules";
            };
          };
          limits_config.retention_period = "30d";
        };
      };

      # Only node IPs may push logs. Query, admin, and deletion APIs stay on
      # loopback; Grafana continues to use the existing local Loki datasource.
      services.caddy = {
        enable = true;
        virtualHosts."http://${cfg.collectorAddress}:3101" = {
          listenAddresses = [ cfg.collectorAddress ];
          extraConfig = ''
            @log_push {
              method POST
              path /loki/api/v1/push
              remote_ip ${lib.concatStringsSep " " allowedAddresses}
            }
            handle @log_push {
              reverse_proxy 127.0.0.1:3100
            }
            handle {
              respond "Not found" 404
            }
          '';
        };
      };

      networking.firewall.extraCommands = lib.mkAfter (
        lib.concatMapStringsSep "\n" (address:
          "iptables -A nixos-fw -p tcp --dport 3101 -s ${address} -j ACCEPT"
        ) allowedAddresses
      );

      systemd.tmpfiles.rules = [
        "d /var/lib/loki/rules 0750 loki loki -"
        "d /var/lib/loki/rules-tmp 0750 loki loki -"
      ];

      grafana.datasources = [
        {
          name = "Loki";
          uid = "loki";
          type = "loki";
          url = "http://127.0.0.1:3100";
        }
      ];
      grafana.dashboards."homelab-logs.json" = ./dashboard.json;
    })
  ];
}
