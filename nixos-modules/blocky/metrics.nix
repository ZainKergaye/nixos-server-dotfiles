{
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.adblock.enable {
    services.blocky.settings.ports.http = 4000;
    grafana.dashboards."blocky.json" = ./dashboard.json;
    services.prometheus.scrapeConfigs = [
      {
        job_name = "blocky";
        static_configs = [
          {
            targets = [ "127.0.0.1:4000" ];
            labels.host = "main";
          }
        ];
      }
    ];
  };
}
