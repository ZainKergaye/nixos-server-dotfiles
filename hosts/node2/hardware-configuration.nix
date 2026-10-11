{
  lib,
  pkgs,
  ...
}:
{
  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ehci_pci"
    "ahci"
    "usbhid"
    "sd_mod"
    "sr_mod"
  ];
  boot.kernelModules = [
    "kvm-intel"
    "wl"
  ];
  boot.kernelPackages = pkgs.linuxPackages_6_6;

  boot.loader = {
    efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot/efi";
    };
    grub = {
      efiSupport = true;
      device = "nodev";
    };
  };

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/433c8775-0644-484a-9655-06f45fd82e7b";
    fsType = "ext4";
  };
  fileSystems."/boot/efi" = {
    device = "/dev/disk/by-uuid/266E-19DF";
    fsType = "vfat";
    options = [
      "fmask=0022"
      "dmask=0022"
    ];
  };
  swapDevices = [ { device = "/dev/disk/by-uuid/3e8c047c-81cb-47d6-8a97-276f78bc0d6f"; } ];

  networking.useDHCP = lib.mkDefault true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = true;
}
