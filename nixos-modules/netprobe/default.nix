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
  ] ++ lib.concatMap (alias: [ "--network-alias=${alias}" ]) aliases;
in
{
  options.netprobe = with lib; {
    enable = mkEnableOption "the Netprobe internet-performance dashboard";

    lanCidr = mkOption {
      type = types.str;
      default = "10.10.10.0/24";
      description = "Trusted LAN allowed to reach Netprobe's Prometheus endpoint";
    };

    wireGuardCidr = mkOption {
      type = types.str;
      default = "10.100.0.0/24";
      description = "WireGuard clients allowed to reach Netprobe's Prometheus endpoint";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.docker.enable = true;
    virtualisation.oci-containers = {
      backend = "docker";
      containers = {
        netprobe-redis = {
          image = "redis:latest";
          autoStart = true;
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

    # Main's Grafana is the only intended consumer of the endpoint. Allow it
    # from the LAN and VPN without publishing it to a future WAN interface.
    networking.firewall.extraCommands = lib.mkAfter ''
      iptables -A nixos-fw -p tcp --dport 9090 -s ${cfg.lanCidr} -j ACCEPT
      iptables -A nixos-fw -p tcp --dport 9090 -s ${cfg.wireGuardCidr} -j ACCEPT
    '';

    # The upstream dashboard is provisioned by the Grafana service on Main;
    # Node 3 only runs the measurements and Prometheus exporter.
    grafana.dashboards."netprobe.json" = lib.mkIf config.grafana.enable (
      netprobeSource + "/config/grafana/dashboards/netprobe.json"
    );
  };
}
