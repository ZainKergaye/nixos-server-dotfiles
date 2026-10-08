{
  config,
  lib,
  ...
}:
let
  cfg = config.scrypted;
in
{
  options.scrypted = with lib; {
    enable = mkEnableOption "a LAN-only Scrypted server for HomeKit Secure Video";

    lanCidr = mkOption {
      type = types.str;
      default = "10.10.10.0/24";
      description = "Trusted LAN allowed to reach Scrypted and its HomeKit accessory ports";
    };

    wireGuardCidr = mkOption {
      type = types.str;
      default = "10.100.0.0/24";
      description = "WireGuard client subnet allowed to reach Scrypted";
    };
  };

  config = lib.mkIf cfg.enable {
    # HomeKit accessory pairing and streaming use mDNS and dynamically assigned
    # listener ports. Host networking makes those services reachable on the LAN.
    # Scrypted supplies its own Avahi instance, so the host daemon must not hold
    # UDP 5353.
    services.avahi.enable = false;

    virtualisation.docker.enable = true;
    virtualisation.oci-containers = {
      backend = "docker";
      containers.scrypted = {
        image = "ghcr.io/koush/scrypted:latest";
        autoStart = true;
        extraOptions = [ "--network=host" ];
        environment = {
          SCRYPTED_DISABLE_AUTHENTICATION = "true";
          SCRYPTED_DOCKER_AVAHI = "true";
          TZ = config.time.timeZone;
        };
        # This volume contains Scrypted's configuration, HomeKit pairings, and
        # plugins. Deliberately do not mount /nvr: no camera video is retained
        # on Node 1; HKSV uploads recordings directly to Apple.
        volumes = [ "/var/lib/scrypted:/server/volume" ];
      };
    };

    # The host-networked HomeKit accessory uses mDNS and dynamic TCP/UDP ports.
    # Restrict all of them to the physical LAN, rather than exposing a broad
    # port range to any future WAN interface.
    networking.firewall.extraCommands = lib.mkAfter ''
      iptables -A nixos-fw -s ${cfg.lanCidr} -j ACCEPT
      iptables -A nixos-fw -s ${cfg.wireGuardCidr} -j ACCEPT
    '';
  };
}
