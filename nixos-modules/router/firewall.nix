{
  config,
  lib,
  ...
}:
{
  options.router = with lib; {
    LANipADDRbase = options.mkOption {
      type = types.str;
      default = "10.10.10.0";
      description = "Local area network ip address base";
      example = "10.10.10.0";
    };
  };

  config = lib.mkIf config.router.enable {
    networking.firewall = {
      enable = lib.mkDefault true;
      # This logs only new refused TCP connections.  Logging every dropped
      # packet is intentionally avoided: WAN background traffic can be very
      # noisy and would obscure useful events.
      logRefusedConnections = true;
      # DHCP clients initially have no address, so they cannot be scoped by
      # source address.  DNS is opened separately by the Blocky module.
      allowedUDPPorts = [ 67 ];
      # Only allow ssh from LAN
      extraCommands = ''
        iptables -A nixos-fw -p tcp --dport 22 -s ${config.router.LANipADDRbase}/${toString config.router.LANipNetmask} -j ACCEPT
      '';
    };
  };
}
