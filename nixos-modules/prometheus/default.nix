{
  config,
  lib,
  ...
}:
{
  options.prometheus = with lib; {
    enable = options.mkEnableOption "Enable prometheus logging";
  };

  config.services.prometheus = lib.mkIf config.prometheus.enable {
    enable = true;
    port = 9090;

    # Scrape metrics every 15 seconds
    globalConfig = {
      scrape_interval = "15s";
      evaluation_interval = "15s";
    };

    # Start with just local node metrics
    scrapeConfigs = [
      {
        job_name = "node";
        static_configs = [
          {
            targets = [ "localhost:9100" ];
          }
        ];
      }
    ];

    exporters.node = {
      enable = true;
      port = 9100;
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
  };
}
