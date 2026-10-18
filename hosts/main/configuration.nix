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
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.defaultSopsFile = ../../secrets/main.yaml;
  sops.secrets.cloudflare-ddns-token = {
    owner = "cloudflare-ddns";
    group = "cloudflare-ddns";
    mode = "0400";
  };
  services.cloudflare-ddns = {
    enable = true;
    credentialsFile = config.sops.secrets.cloudflare-ddns-token.path;
    domains = [ "vpn.kergaye.com" ];
    updateCron = "@every 30m";
  };
  adblock.enable = true;
  prometheus.server.enable = true;
  grafana.enable = true;
  netprobe.grafana.enable = true;
  grafana.datasources = [
    {
      name = "Loki";
      uid = "loki";
      type = "loki";
      url = "http://127.0.0.1:3100";
    }
  ];
  wireguardGateway = {
    enable = true;
    peers = [
      {
        name = "thinkpad";
        publicKey = "xEEAGu1rKyrrT8S72v8pqUB2XrDkhoHJnwjcU6Ys2jQ=";
        allowedIP = "10.100.0.2/32";
      }
      {
        name = "iPhone";
        publicKey = "Lox4BpBF+zFFnibZJEB2vFgqlASwV6wP1uMa6mVngSE=";
        allowedIP = "10.100.0.3/32";
      }
      {
        name = "iPad";
        publicKey = "zMMBtTykYLBoiaP5CUzQ79tJJ8oeitiaAXDtA+662SM=";
        allowedIP = "10.100.0.4/32";
      }
    ];
  };
  ups.server.enable = true;
  reverse_proxy = {
    enable = true;
    routes = {
      # Add one entry per HTTP service.  The hostname resolves to main, then
      # Caddy proxies it to the node and port shown here.
      "immich.s" = "10.10.10.15:2283";
      "scrypted.s" = "10.10.10.11:11080";
      "homebridge.s" = "10.10.10.11:8581";
      "ai.s" = "10.10.10.15:8081";
      "grafana.s" = "127.0.0.1:3000";
      "blocky.s" = "127.0.0.1:4000"; # For blocking button on grafana dashboard
      "nas.s" = "10.10.10.39:8080";
    };
  };
  router = {
    enable = true;
    WANif = "eno1";
    LANif = "enp2s0";
  };

  # Make Scrypted's and Homebridge's dynamic HomeKit accessory ports reachable
  # only from the trusted home network on the WAN side. Home-network clients
  # need a route for 10.10.10.0/24 via main's WAN address; see
  # docs/lan-services.md.
  networking.nat.extraCommands = ''
    iptables -w -t filter -A nixos-filter-forward -i ${config.router.WANif} -o ${config.router.LANif} -s 10.0.0.0/24 -d 10.10.10.11 -j ACCEPT
  '';

  # HomeKit discovers the host-networked Scrypted accessory using mDNS. mDNS
  # is link-local, so reflect it explicitly between the home (WAN) and server
  # LAN networks; do not reflect it to any other interface.
  services.avahi = {
    enable = true;
    reflector = true;
    allowInterfaces = [
      config.router.WANif
      config.router.LANif
    ];
    openFirewall = true;
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
