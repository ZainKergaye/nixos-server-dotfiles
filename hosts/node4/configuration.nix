{ ... }: {
  lanNode = {
    enable = true;
    address = "10.10.10.14";
  };
  imports = [ ./disk.nix ];

  hardware.cpu.intel.updateMicrocode = true;
  boot.loader = {
    timeout = 4;
    efi.canTouchEfiVariables = true;
    systemd-boot = {
      enable = true;
    };
  };
}
