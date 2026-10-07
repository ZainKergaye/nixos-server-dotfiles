{
  config,
  lib,
  ...
}:
let
  cfg = config.ups;
in
{
  options.ups = with lib; {
    enable = mkEnableOption "Network UPS Tools monitoring";
    server.enable = mkEnableOption "the NUT server connected directly to the UPS";
    passwordFile = mkOption {
      type = types.str;
      default = "/etc/nut/ups-monitor-password";
      description = "Runtime file containing the shared NUT monitor password";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        power.ups = {
          enable = true;
          mode = if cfg.server.enable then "netserver" else "netclient";
          upsmon.monitor."UPS-1" = {
            system = "UPS-1@${if cfg.server.enable then "localhost" else config.router.LANipADDR}";
            powerValue = 1;
            user = "upsmon";
            passwordFile = cfg.passwordFile;
            type = if cfg.server.enable then "primary" else "secondary";
          };
        };
      }
      (lib.mkIf cfg.server.enable {
        power.ups = {
          ups."UPS-1" = {
            description = "CyberPower CP1500C";
            driver = "usbhid-ups";
            port = "auto";
          };
          upsd.listen = [
            {
              address = "127.0.0.1";
              port = 3493;
            }
            {
              address = config.router.LANipADDR;
              port = 3493;
            }
          ];
          users.upsmon = {
            passwordFile = cfg.passwordFile;
            upsmon = "primary";
          };
        };
        services.prometheus = {
          exporters.nut = {
            enable = true;
            listenAddress = "127.0.0.1";
            port = 9199;
            nutServer = "127.0.0.1";
            nutVariables = [
              "battery.charge"
              "battery.runtime"
              "battery.voltage"
              "input.voltage"
              "ups.load"
              "ups.status"
            ];
          };
          scrapeConfigs = [
            {
              job_name = "ups";
              metrics_path = "/ups_metrics";
              static_configs = [
                {
                  targets = [ "127.0.0.1:9199" ];
                  labels.host = "main";
                }
              ];
            }
          ];
        };
        networking.firewall.extraCommands = lib.mkAfter ''
          iptables -A nixos-fw -p tcp --dport 3493 -s ${config.router.LANipADDRbase}/${toString config.router.LANipNetmask} -j ACCEPT
        '';
        grafana.dashboards."ups.json" = ./dashboard.json;
      })
    ]
  );
}
