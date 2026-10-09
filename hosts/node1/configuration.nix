{ ... }: {
  imports = [ ./disk.nix ];
  lanNode = {
    enable = true;
    address = "10.10.10.11";
  };

  scrypted.enable = true;
  immich.enable = true;

  hardware.cpu.intel.updateMicrocode = true;
  boot.loader = {
    timeout = 4;
    efi.canTouchEfiVariables = true;
    systemd-boot = {
      enable = true;
    };
  };
}
