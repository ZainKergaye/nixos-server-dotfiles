{
  config,
  lib,
  ...
}:
let
  cfg = config.homebridge;
in
{
  options.homebridge = with lib; {
    enable = mkEnableOption "a Homebridge server for HomeKit accessories";

    lanCidr = mkOption {
      type = types.str;
      default = "10.10.10.0/24";
      description = "Trusted LAN allowed to reach Homebridge and its HomeKit accessory ports";
    };

    wireGuardCidr = mkOption {
      type = types.str;
      default = "10.100.0.0/24";
      description = "WireGuard client subnet allowed to reach Homebridge";
    };

    allowWan = mkOption {
      type = types.bool;
      default = false;
      description = "Allow Homebridge and its HomeKit accessory ports from the router's WAN side";
    };
  };

  config = lib.mkIf cfg.enable {
    # Keep Homebridge's editable UI configuration, pairings, and downloaded
    # plugins in /var/lib/homebridge. Do not use its broad openFirewall option:
    # HomeKit uses mDNS and dynamic ports, which are scoped below instead.
    services.homebridge = {
      enable = true;
      openFirewall = false;
    };

    # HomeKit pairing and accessory communication use mDNS and dynamic
    # TCP/UDP ports. When WAN access is enabled, main remains the perimeter:
    # it forwards only WAN traffic addressed to Node 1. This admits those
    # forwarded packets after they arrive on Node 1's LAN interface.
    networking.firewall.extraCommands = lib.mkAfter ''
      iptables -A nixos-fw -s ${cfg.lanCidr} -j ACCEPT
      iptables -A nixos-fw -s ${cfg.wireGuardCidr} -j ACCEPT
      ${lib.optionalString cfg.allowWan "iptables -A nixos-fw -j ACCEPT"}
    '';
  };
}
