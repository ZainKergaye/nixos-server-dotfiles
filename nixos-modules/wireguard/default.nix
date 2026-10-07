{
  config,
  lib,
  ...
}:
let
  cfg = config.wireguardGateway;
in
{
  options.wireguardGateway = with lib; {
    enable = mkEnableOption "a WireGuard gateway for remote LAN and Internet access";
    interface = mkOption {
      type = types.str;
      default = "wg0";
      description = "WireGuard interface name";
    };
    address = mkOption {
      type = types.str;
      default = "10.100.0.1/24";
      description = "Gateway address and prefix of the WireGuard network";
    };
    subnet = mkOption {
      type = types.str;
      default = "10.100.0.0/24";
      description = "WireGuard client subnet used for firewall policy";
    };
    port = mkOption {
      type = types.port;
      default = 51820;
      description = "UDP port on which WireGuard accepts remote clients";
    };
    privateKeyFile = mkOption {
      type = types.str;
      default = "/var/lib/wireguard/server.key";
      description = "Runtime path for the generated WireGuard server private key";
    };
    peers = mkOption {
      default = [ ];
      type = types.listOf (types.submodule {
        options = {
          name = mkOption { type = types.str; };
          publicKey = mkOption {
            type = types.str;
            description = "Peer WireGuard public key";
          };
          allowedIP = mkOption {
            type = types.str;
            example = "10.100.0.2/32";
            description = "Unique tunnel address assigned to this peer";
          };
          presharedKeyFile = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Optional runtime file containing this peer's preshared key";
          };
        };
      });
      description = "Remote WireGuard clients allowed to use this gateway";
    };
  };

  config = lib.mkIf cfg.enable {
    networking = {
      wireguard.interfaces.${cfg.interface} = {
        ips = [ cfg.address ];
        listenPort = cfg.port;
        inherit (cfg) privateKeyFile;
        generatePrivateKeyFile = true;
        peers = map (peer: {
          inherit (peer) name publicKey;
          allowedIPs = [ peer.allowedIP ];
          inherit (peer) presharedKeyFile;
        }) cfg.peers;
      };

      # Full-tunnel client traffic must be eligible for the existing WAN NAT.
      nat.internalInterfaces = lib.mkForce [ config.router.LANif cfg.interface ];

      firewall = {
        allowedUDPPorts = [ cfg.port ];
        # Authenticated VPN clients may reach services on the router itself.
        trustedInterfaces = [ cfg.interface ];
      };
    };

    # NAT accepts VPN -> WAN traffic.  This additional rule grants VPN -> LAN
    # access; replies are covered by NAT's ESTABLISHED,RELATED rule.
    networking.nat.extraCommands = ''
      iptables -w -t filter -A nixos-filter-forward -i ${cfg.interface} -o ${config.router.LANif} -j ACCEPT
    '';

    # Per-peer metrics stay on loopback because Prometheus runs on this host.
    services.prometheus.exporters.wireguard = {
      enable = true;
      listenAddress = "127.0.0.1";
      port = 9586;
      interfaces = [ cfg.interface ];
      latestHandshakeDelay = true;
    };
    systemd.services.prometheus-wireguard-exporter.after = [ "wireguard-${cfg.interface}.service" ];

    services.prometheus.scrapeConfigs = [
      {
        job_name = "wireguard";
        static_configs = [
          {
            targets = [ "127.0.0.1:9586" ];
            labels.host = "main";
          }
        ];
      }
    ];

    grafana.dashboards."wireguard.json" = ./dashboard.json;
  };
}
