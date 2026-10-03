{
  config,
  lib,
  ...
}:
let
  cfg = config.lanNode;
  network = {
    address = [ "${cfg.address}/${toString cfg.prefixLength}" ];
    routes = [
      {
        Gateway = cfg.gateway;
      }
    ];
    dns = [ cfg.dns ];
    linkConfig.RequiredForOnline = "routable";
  };
in
{
  options.lanNode = with lib; {
    enable = mkEnableOption "a statically addressed LAN node";
    address = mkOption {
      type = types.str;
      description = "Static IPv4 address assigned to this node";
    };
    prefixLength = mkOption {
      type = types.int;
      default = 24;
      description = "LAN IPv4 prefix length";
    };
    gateway = mkOption {
      type = types.str;
      default = "10.10.10.1";
      description = "LAN router address";
    };
    dns = mkOption {
      type = types.str;
      default = "10.10.10.1";
      description = "LAN DNS resolver address";
    };
  };

  config = lib.mkIf cfg.enable {
    networking = {
      useDHCP = false;
      networkmanager.enable = false;
    };

    systemd.network = {
      enable = true;
      # Physical systems commonly use enp*/eno*; the NixOS QEMU VM uses eth*.
      networks."10-lan-physical" = {
        matchConfig.Name = "en*";
        inherit (network) address routes dns linkConfig;
      };
      networks."11-lan-vm" = {
        matchConfig.Name = "eth*";
        inherit (network) address routes dns linkConfig;
      };
    };
  };
}
