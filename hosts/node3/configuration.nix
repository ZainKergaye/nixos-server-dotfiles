{ ... }: {
  imports = [
    ./disk.nix
    ./gpu.nix
  ];

  # Required for the proprietary NVIDIA 580 driver used by both Pascal cards.
  nixpkgs.config.allowUnfree = true;
  lanNode = {
    enable = true;
    address = "10.10.10.15";
  };

  codingAgent.enable = true;
  # netprobe.enable = true;

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ahci"
    "nvme"
  ];
  boot.kernelModules = [ "kvm-intel" ];

  hardware.cpu.intel.updateMicrocode = true;
  boot.loader = {
    timeout = 4;
    efi.canTouchEfiVariables = true;
    systemd-boot = {
      enable = true;
    };
  };
}
