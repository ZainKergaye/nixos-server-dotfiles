{
  lib,
  config,
  ...
}:
let
  cfg = config.reverse_proxy;
in
{
  options.reverse_proxy = with lib; {
    enable = mkEnableOption "LAN-only reverse proxy stack";
    routes = mkOption {
      type = types.attrsOf types.str;
      default = { };
      example = {
        "immich.home" = "10.10.10.11:2283";
        "jellyfin.home" = "10.10.10.11:8096";
      };
      description = ''
        Map each LAN hostname to an HTTP upstream in host:port form.  Each
        hostname resolves to the router, which proxies it to the upstream.
      '';
    };
  };

  config = lib.mkIf (cfg.enable && cfg.routes != { }) {
    services.caddy = {
      enable = true;
      virtualHosts = lib.mapAttrs' (
        hostname: upstream:
        lib.nameValuePair "http://${hostname}" {
          # Do not listen on the WAN interface, and deliberately use HTTP.
          # `.home` names cannot obtain a public ACME certificate.
          listenAddresses = [ config.router.LANipADDR ];
          extraConfig = ''
            reverse_proxy ${upstream}
          '';
        }
      ) cfg.routes;
    };

    # Proxy hostnames must resolve to the router, not their backend node.
    services.blocky.settings.customDNS.mapping = lib.mapAttrs (
      _: _: config.router.LANipADDR
    ) cfg.routes;

    networking.firewall.extraCommands = lib.mkAfter ''
      iptables -A nixos-fw -p tcp --dport 80 -s ${config.router.LANipADDRbase}/${toString config.router.LANipNetmask} -j ACCEPT
    '';
  };
}
