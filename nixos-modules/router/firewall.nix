{
  config,
  lib,
  ...
}:
{
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
