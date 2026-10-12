{
  config,
  lib,
  inputs,
  ...
}:
let
  cfg = config.netprobe;
  containerNames = [
    "netprobe-redis"
    "netprobe-probe"
    "netprobe-speedtest"
    "netprobe-presentation"
    "netprobe-prometheus"
  ];
  netprobeSource = inputs.netprobe;
  networkOptions = aliases: [
    "--network=netprobe"
    # Netprobe intentionally queries public resolvers as part of its internet
    # health measurements.  Keep its own resolver path independent of the
    # LAN's DNS filtering service, as in the upstream Compose deployment.
    "--dns=8.8.8.8"
    "--dns=8.8.4.4"
  ] ++ lib.concatMap (alias: [ "--network-alias=${alias}" ]) aliases;
in
{
  options.netprobe = with lib; {
    enable = mkEnableOption "the Netprobe internet-performance dashboard";

    metrics.target = mkOption {
      type = types.str;
      default = "10.10.10.11";
      description = "Address of the Netprobe Prometheus service";
    };

    grafana.enable = mkEnableOption "the Netprobe datasource and dashboard";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
    virtualisation.docker.enable = true;
    virtualisation.oci-containers = {
      backend = "docker";
      containers = {
        netprobe-redis = {
          image = "redis:latest";
          autoStart = true;
          volumes = [
            "${netprobeSource}/config/redis/redis.conf:/etc/redis/redis.conf:ro"
          ];
          extraOptions = networkOptions [ "redis" "netprobe-redis" ];
        };

        netprobe-probe = {
          image = "plaintextpackets/netprobe:latest";
          autoStart = true;
          environment.MODULE = "NETPROBE";
          volumes = [
            "${netprobeSource}:/netprobe_lite:ro"
            "netprobe-logs:/netprobe_lite/logs"
          ];
          extraOptions = networkOptions [ "netprobe" "netprobe-probe" ];
        };

        netprobe-speedtest = {
          image = "plaintextpackets/netprobe:latest";
          autoStart = true;
          environment.MODULE = "SPEEDTEST";
          volumes = [
            "${netprobeSource}:/netprobe_lite:ro"
            "netprobe-logs:/netprobe_lite/logs"
          ];
          extraOptions = networkOptions [ "speedtest" "netprobe-speedtest" ];
        };

        netprobe-presentation = {
          image = "plaintextpackets/netprobe:latest";
          autoStart = true;
          environment.MODULE = "PRESENTATION";
          volumes = [
            "${netprobeSource}:/netprobe_lite:ro"
            "netprobe-logs:/netprobe_lite/logs"
          ];
          extraOptions = networkOptions [ "presentation" "netprobe-presentation" ];
        };

        netprobe-prometheus = {
          image = "prom/prometheus:latest";
          autoStart = true;
          ports = [ "9090:9090" ];
          cmd = [
            "--config.file=/etc/prometheus/prometheus.yml"
            "--storage.tsdb.path=/prometheus"
            "--storage.tsdb.retention.time=30d"
          ];
          volumes = [
            "${netprobeSource}/config/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro"
            "netprobe-prometheus-data:/prometheus"
          ];
          extraOptions = networkOptions [ "prometheus" "netprobe-prometheus" ];
        };

      };
    };

    # OCI containers use a user-defined Docker network so the upstream service
    # names remain resolvable. It is intentionally retained across rebuilds.
    systemd.services = (lib.genAttrs (map (name: "docker-${name}") containerNames) (_: {
      after = [ "docker-netprobe-network.service" ];
      requires = [ "docker-netprobe-network.service" ];
    })) // {
      docker-netprobe-network = {
        description = "Netprobe Docker network";
        after = [ "docker.service" ];
        requires = [ "docker.service" ];
        wantedBy = [ "multi-user.target" ];
        before = map (name: "docker-${name}.service") containerNames;
        serviceConfig.Type = "oneshot";
        script = ''
          if ! ${config.virtualisation.docker.package}/bin/docker network inspect netprobe >/dev/null 2>&1; then
            ${config.virtualisation.docker.package}/bin/docker network create netprobe
          fi
        '';
      };
    };

    # Main's Grafana and Prometheus are the only intended consumers of this
    # endpoint. Keep the container's metrics port inaccessible to other LAN
    # and VPN clients, just like the other node-level exporters.
    networking.firewall.extraCommands = lib.mkAfter ''
      iptables -A nixos-fw -p tcp --dport 9090 -s ${config.prometheus.collectorAddress} -j ACCEPT
    '';
    })

    # Enable this on the Grafana host. Keeping the datasource and dashboard
    # beside Netprobe's service definition prevents host configurations from
    # duplicating Netprobe-specific Grafana provisioning details.
    (lib.mkIf cfg.grafana.enable {
      assertions = [
        {
          assertion = config.grafana.enable;
          message = "netprobe.grafana.enable requires grafana.enable";
        }
      ];

      # Grafana otherwise assigns the default Prometheus datasource a random
      # UID.  Netprobe's upstream dashboard has a fixed UID, so pin
      # Prometheus here as well to prevent it from taking Netprobe's UID.
      services.grafana.provision.datasources.settings.datasources = lib.mkForce (
        [
          {
            name = "Prometheus";
            uid = "Prometheus";
            type = "prometheus";
            url = "http://localhost:9090";
            isDefault = true;
          }
        ]
        ++ config.grafana.datasources
      );

      grafana.datasources = [
        {
          name = "Netprobe";
          # This stable UID is referenced by Netprobe's upstream dashboard.
          uid = "PBFA97CFB590B2093";
          type = "prometheus";
          url = "http://${cfg.metrics.target}:9090";
        }
      ];
      grafana.dashboards."netprobe.json" =
        netprobeSource + "/config/grafana/dashboards/netprobe.json";
    })
  ];
}
