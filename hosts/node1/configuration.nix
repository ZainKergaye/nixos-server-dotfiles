{ ... }: {
  imports = [ ./disk.nix ];
  lanNode = {
    enable = true;
    address = "10.10.10.11";
  };

  scrypted = {
    enable = true;
    # The router limits this to traffic entering its WAN interface and
    # addressed to Node 1. HomeKit needs dynamic accessory ports, so a
    # port-only rule would not be sufficient.
    allowWan = true;
  };
  netprobe.enable = true;

  hardware.cpu.intel.updateMicrocode = true;
  boot.loader = {
    timeout = 4;
    efi.canTouchEfiVariables = true;
    systemd-boot = {
      enable = true;
    };
  };
}
