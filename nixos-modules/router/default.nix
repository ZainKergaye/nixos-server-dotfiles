{
  config,
  lib,
  ...
}:
{
  imports = [ ./firewall.nix ];

  options.router = with lib; {
    enable = options.mkEnableOption "Enable router stack";
    WANif = options.mkOption {
      type = types.str;
      description = "Wide area network interface name";
      example = "enp1s0";
    };
    LANif = options.mkOption {
      type = types.str;
      description = "Local area network interface name";
      example = "enp2s0";
    };
    LANipADDR = options.mkOption {
      type = types.str;
      default = "10.10.10.1";
      description = "Local area network ip address";
      example = "10.10.10.1";
    };
    LANipNetmask = options.mkOption {
      type = types.int;
      default = 24;
      description = "Local area network network mask";
      example = 24;
    };
    LANDHCPRange = options.mkOption {
      type = types.str;
      default = "10.10.10.2,10.10.10.250";
      description = "Local area network DHCP range";
      example = "10.10.10.2,10.10.10.250";
    };
    lanHosts = options.mkOption {
      type = types.attrsOf types.str;
      default = {
        "main.home" = "10.10.10.1";
        "node1.home" = "10.10.10.11";
        "node2.home" = "10.10.10.12";
        "node3.home" = "10.10.10.13";
        "node4.home" = "10.10.10.14";
      };
      description = "Static LAN hostname-to-address mappings served by Blocky";
    };
    ids.enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Suricata IDS inspection of Internet-facing router traffic";
    };
  };

  config = lib.mkIf config.router.enable {
    # Keep router, DHCP, DNS, and firewall events across reboots.  A finite
    # retention limit prevents a noisy WAN scan from consuming the disk.
    services.journald.settings.Journal = {
      Storage = "persistent";
      SystemMaxUse = "1G";
      MaxRetentionSec = "30day";
    };

    boot.kernel.sysctl = {
      # IP forwarding
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
      # Don’t accept ICMP redirects from an untrusted WAN.
      "net.ipv4.conf.all.accept_redirects" = 0;
      "net.ipv4.conf.default.accept_redirects" = 0;
    };
    networking = {
      networkmanager.enable = false;
      useDHCP = false;

      # WAN
      interfaces.${config.router.WANif} = {
        useDHCP = true; # IP from isp
      };

      # LAN
      interfaces.${config.router.LANif} = {
        ipv4.addresses = [
          {
            address = config.router.LANipADDR;
            prefixLength = config.router.LANipNetmask;
          }
        ];
      };

      # NAT
      nat = {
        enable = true;
        externalInterface = config.router.WANif;
        internalInterfaces = [ config.router.LANif ];
      };
    };

    services.dnsmasq = {
      enable = true;
      settings = {
        # Blocky owns port 53.  dnsmasq is used strictly for DHCP so the two
        # services can run together on the router.
        port = 0;
        dhcp-range = [ config.router.LANDHCPRange ];
        interface = config.router.LANif;
        bind-interfaces = true;

        dhcp-option = [
          "option:router,${config.router.LANipADDR}"
          # Blocky runs on the router and is the LAN DNS resolver.
          "option:dns-server,${config.router.LANipADDR}"
        ];
      };
    };

    services.suricata = lib.mkIf config.router.ids.enable {
      enable = true;
      # Rule updates run daily and are loaded without waiting for a reboot.
      reloadOnRulesetUpdate = true;
      settings = {
        vars.address-groups.HOME_NET = "${config.router.LANipADDRbase}/${toString config.router.LANipNetmask}";
        af-packet = [
          {
            # Capturing only WAN sees both ingress and egress Internet flows;
            # also capturing LAN would duplicate each forwarded flow.
            interface = config.router.WANif;
            cluster-id = "99";
            cluster-type = "cluster_flow";
            defrag = "yes";
          }
        ];
        stats = {
          enable = true;
          interval = "60";
        };
        outputs = [
          {
            eve-log = {
              enabled = true;
              filetype = "regular";
              filename = "eve.json";
              community-id = true;
              types = [
                { alert = { }; }
                { flow = { }; }
                { stats = { }; }
              ];
            };
          }
          {
            fast = {
              enabled = true;
              filename = "fast.log";
              append = "yes";
            };
          }
        ];
      };
    };

    services.blocky.settings.customDNS = lib.mkIf config.adblock.enable {
      customTTL = "1h";
      mapping = config.router.lanHosts;
    };

    grafana.dashboards."router.json" = ./dashboard.json;
  };
}
