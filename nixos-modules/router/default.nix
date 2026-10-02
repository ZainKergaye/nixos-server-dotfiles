{
  config,
  lib,
  ...
}:
{
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
    LANipADDRbase = options.mkOption {
      type = types.str;
      default = "10.10.10.0";
      description = "Local area network ip address base";
      example = "10.10.10.0";
    };
    LANipNetmask = options.mkOption {
      type = types.int;
      default = 24;
      description = "Local area network network mask";
      example = 24;
    };
    LANDHCPRange = options.mkOption {
      type = types.str;
      default = "10.10.10.2,10.10.10.256";
      description = "Local area network DHCP range";
      example = "10.10.10.2,10.10.10.256";
    };
  };

  config = lib.mkIf config.router.enable {
    boot.kernel.sysctl = {
      # IP forwarding
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
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
        dhcp-range = [ config.router.LANDHCPRange ];
        interface = config.router.LANif;

        # DNS
        server = [
          (lib.mkIf (!config.adblock.enable) "1.1.1.1")
          (lib.mkIf config.adblock.enable config.router.LANipADDR)
        ];

        # Don't use /etc/hosts
        no-hosts = true;

        dhcp-option = [
          "option:router,${config.router.LANipADDR}"
          (lib.mkIf config.adblock.enable "option:dns-server,${config.router.LANipADDR}")
        ];
      };
    };
  };
}
