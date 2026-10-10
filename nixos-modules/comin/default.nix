{
  config,
  lib,
  ...
}:
let
  cfg = config.cominDeployment;
in
{
  options.cominDeployment = with lib; {
    enable = mkEnableOption "Comin pull-based NixOS deployments";
    repository = mkOption {
      type = types.str;
      default = "https://github.com/ZainKergaye/nixos-server-dotfiles.git";
      description = "Git repository Comin polls for system configurations";
    };
    branch = mkOption {
      type = types.str;
      default = "master";
      description = "Git branch Comin deploys";
    };
    pollInterval = mkOption {
      type = types.ints.positive;
      default = 60;
      description = "Seconds between repository polls";
    };
    collectorAddress = mkOption {
      type = types.str;
      default = "10.10.10.1";
      description = "Central Prometheus collector permitted to scrape Comin metrics";
    };
  };

  config = lib.mkIf cfg.enable {
    services.comin = {
      enable = true;
      hostname = config.networking.hostName;
      remotes = [
        {
          name = "origin";
          url = cfg.repository;
          branches.${cfg.branch}.name = cfg.branch;
          poller.period = cfg.pollInterval;
        }
      ];
      retention = {
        deployment_any_capacity = 8;
        deployment_successful_capacity = 5;
        deployment_boot_entry_capacity = 3;
      };
      exporter = {
        listen_address = "0.0.0.0";
        port = 4243;
        openFirewall = false;
      };
    };

    networking.firewall.extraCommands = lib.mkAfter ''
      iptables -A nixos-fw -p tcp --dport 4243 -s ${cfg.collectorAddress} -j ACCEPT
    '';

    # The central Comin instance owns the complete target list, while each
    # host owns only its local exporter above.
    services.prometheus.scrapeConfigs = lib.mkIf config.prometheus.server.enable [
      {
        job_name = "comin";
        static_configs = lib.mapAttrsToList (name: address: {
          targets = [ "${address}:4243" ];
          labels.host = lib.removeSuffix ".home" name;
        }) config.router.lanHosts;
      }
    ];

    grafana.dashboards."comin.json" = lib.mkIf config.grafana.enable ./dashboard.json;
  };
}
