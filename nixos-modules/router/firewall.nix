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
    firewall = {
      enable = lib.mkDefault true;
      # Only allow ssh from LAN
      extraCommands = ''
        iptables -A nixos-fw -p tcp --dport 22 -s ${config.router.LANipADDRbase}/${config.router.LANipNetmask} -j ACCEPT
      '';
    };
  };
}
