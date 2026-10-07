{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.grafana;
  dashboardDirectory = pkgs.linkFarm "grafana-dashboards" (
    lib.mapAttrsToList (name: path: { inherit name path; }) cfg.dashboards
  );
in
{
  options.grafana = with lib; {
    enable = options.mkEnableOption "Enable grafana dashboard";
    datasources = options.mkOption {
      type =
        with types;
        listOf (submodule {
          options = {
            name = mkOption {
              type = str;
            };
            type = mkOption {
              type = str;
            };
            url = mkOption {
              type = str;
            };
            isDefault = mkEnableOption;
          };
        });
      description = "Datasources";
      example = [
        {
          name = "Prometheus";
          type = "prometheus";
          url = "http://localhost:9090";
          isDefault = true;
        }
      ];
    };
    dashboards = options.mkOption {
      type = types.attrsOf types.path;
      default = { };
      description = "Named Grafana dashboard JSON files contributed by monitored services";
    };
  };

  config = lib.mkIf cfg.enable {
    services.grafana = {
      enable = true;
      settings = {
        server = {
          http_addr = "0.0.0.0";
          http_port = 3000;
          domain = "localhost";
        };

        analytics.reporting_enabled = false;

        # Kept outside the Nix store and generated only once.  Grafana uses it
        # to encrypt local data and sign sessions, so changing it would
        # invalidate existing sessions and encrypted values.
        security.secret_key = "$__file{/var/lib/grafana/secret-key}";

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
        ]
        ++ cfg.datasources;
        dashboards.settings.providers = [
          {
            name = "NixOS services";
            orgId = 1;
            folder = "Infrastructure";
            type = "file";
            disableDeletion = false;
            editable = true;
            options.path = dashboardDirectory;
          }
        ];
      };
    };

    systemd.services.grafana.preStart = lib.mkBefore ''
      if ! test -s /var/lib/grafana/secret-key; then
        umask 077
        ${pkgs.openssl}/bin/openssl rand -hex 32 > /var/lib/grafana/secret-key
      fi
    '';
  };
}
