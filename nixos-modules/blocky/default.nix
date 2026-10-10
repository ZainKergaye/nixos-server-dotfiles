{
  lib,
  config,
  ...
}:
{
  imports = [
    ./lists.nix
    ./metrics.nix
  ];
  options.adblock.enable = lib.options.mkEnableOption "Enable adblock stack";

  config = lib.mkIf config.adblock.enable {
    networking.firewall = {
      allowedTCPPorts = [ 53 ];
      allowedUDPPorts = [ 53 ];
    };
    services.blocky = {
      enable = true;
      enableConfigCheck = true;
      settings = {
        ports.dns = 53;
        upstreams.groups.default = [
          "1.1.1.1" # Cloudflare
          "208.67.222.222" # OpenDNS
          "9.9.9.9" # Quad9
        ];
        bootstrapDns = {
          upstream = "https://one.one.one.one/dns-query";
          ips = [
            "1.1.1.1"
            "1.0.0.1"
          ];
        };

        caching = {
          minTime = "60s";
          maxItemsCount = 10000;
          prefetching = true;
          prefetchMaxItemsCount = 2000;
        };
      };
    };
  };
}
