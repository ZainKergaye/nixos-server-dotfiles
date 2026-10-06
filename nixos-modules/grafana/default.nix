{
  config,
  lib,
  ...
}:
{
  options.grafana = with lib; {
    enable = options.mkEnableOption "Enable grafana dashboard";
  };

  config.services = lib.mkIf config.grafana.enable {
    grafana = {
      enable = true;
      settings = {
        server = {
          http_addr = "0.0.0.0";
          http_port = 3000;
          domain = "192.168.1.1";
        };

        analytics.reporting_enabled = false;

        # Anonymous access for read-only dashboards
        "auth.anonymous" = {
          enabled = true;
          org_role = "Viewer";
        };
      };

      # Automatically configure Prometheus datasource
      provision = {
        datasources.settings.datasources = [
          {
            name = "Prometheus";
            type = "prometheus";
            url = "http://localhost:9090";
            isDefault = true;
          }
        ];
      };
    };
  };
}
