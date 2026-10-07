{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.prometheus;
  nodeTargets = lib.mapAttrsToList (name: address: {
    targets = [ "${address}:9100" ];
    labels.host = lib.removeSuffix ".home" name;
  }) config.router.lanHosts;
in
{
  options.prometheus = with lib; {
    enable = mkEnableOption "Prometheus node-exporter metrics";
    collectorAddress = mkOption {
      type = types.str;
      default = "10.10.10.1";
      description = "Address of the central Prometheus server allowed to scrape this host";
    };
    server.enable = mkEnableOption "the central Prometheus server";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      services.prometheus.exporters.node = {
        enable = true;
        port = 9100;
        listenAddress = "0.0.0.0";
        enabledCollectors = [
          "systemd"
          "diskstats"
          "filesystem"
          "loadavg"
          "meminfo"
          "netdev"
          "stat"
          "time"
          "uname"
        ];
      };

      # Only the central collector can access an exporter's HTTP endpoint.
      networking.firewall.extraCommands = lib.mkAfter ''
        iptables -A nixos-fw -p tcp --dport 9100 -s ${cfg.collectorAddress} -j ACCEPT
      '';
    })

    (lib.mkIf cfg.server.enable {
      services.prometheus = {
        enable = true;
        port = 9090;
        # Grafana runs on this machine, so there is no reason to publish the
        # Prometheus UI/API to the LAN.
        listenAddress = "127.0.0.1";

        globalConfig = {
          scrape_interval = "15s";
          evaluation_interval = "15s";
        };

        scrapeConfigs = [
          {
            job_name = "nodes";
            static_configs = nodeTargets;
          }
        ];
      };

      grafana.dashboards."node-overview.json" = ./dashboards/node-overview.json;
    })
  ];
}
