{
  lib,
  config,
  ...
}:
{
  options.reverse_proxy.enable = lib.options.mkEnableOption "Enable reverse proxy stack";

  config.services = lib.mkIf (config.adblock.enable && config.reverse_proxy.enable) {
    blocky = {
      settings.customDNS = {
        customTTL = "1h";
        mapping = {
          "example.home" = "192.168.1.1";
        };
      };
    };
  };
}
