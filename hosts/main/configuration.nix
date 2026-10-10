{
  lib,
  config,
  ...
}:
{
  imports = [
    ./gpu.nix
    ./disk.nix
  ];
  networking.firewall = {
    enable = true;
  };
  networking.nameservers = [ "localhost" ];
  adblock.enable = true;
  prometheus.server.enable = true;
  grafana.enable = true;
  wireguardGateway = {
    enable = true;
    peers = [
      {
        name = "thinkpad";
        publicKey = "6EST+2tQDNaSYbSMT+FhcU1b8WjudqkRhghko7adckU=";
        allowedIP = "10.100.0.2/32";
      }
    ];
  };
  ups.server.enable = true;
  reverse_proxy = {
    enable = true;
    routes = {
      # Add one entry per HTTP service.  The hostname resolves to main, then
      # Caddy proxies it to the node and port shown here.
      "immich.home" = "10.10.10.11:2283";
      "scrypted.home" = "10.10.10.11:11080";
      # "jellyfin.home" = "10.10.10.11:8096";
      "apple.home" = "${config.router.lanHosts."node1.home"}:3232";
      "grafana.home" = "127.0.0.1:3000";
    };
  };
  router = {
    enable = true;
    WANif = "eno1";
    LANif = "enp2s0";
  };

  # `nix run .#main` gets a NAT-backed WAN and a socket-backed LAN.  This
  # variant affects only the test VM; the real machine continues to use the
  # interface names above.
  virtualisation.vmVariant = {
    ups.enable = lib.mkForce false;
    disko.devices.disk.main.device = lib.mkForce "/dev/vda";
    router.WANif = lib.mkForce "wan0";
    router.LANif = lib.mkForce "lan0";

    virtualisation.qemu.networkingOptions = lib.mkForce [
      "-netdev user,id=wan,\${QEMU_NET_OPTS:+,$QEMU_NET_OPTS}"
      "-device virtio-net-pci,netdev=wan,mac=52:54:00:00:00:01"
      "-netdev socket,id=lan,listen=127.0.0.1:12345"
      "-device virtio-net-pci,netdev=lan,mac=52:54:00:00:00:02"
    ];

    services.udev.extraRules = ''
      SUBSYSTEM=="net", ACTION=="add", ATTR{address}=="52:54:00:00:00:01", NAME="wan0"
      SUBSYSTEM=="net", ACTION=="add", ATTR{address}=="52:54:00:00:00:02", NAME="lan0"
    '';
  };
  hardware.cpu.intel.updateMicrocode = true;
  boot.loader = {
    timeout = 4;
    efi.canTouchEfiVariables = true;
    systemd-boot = {
      enable = true;
    };
  };
}
