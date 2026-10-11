{ pkgs, ... }:
{
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  boot.blacklistedKernelModules = [ "nouveau" ];
  services.xserver.videoDrivers = [ "nvidia" "modesetting" ];
  services.xserver.config = ''
    Section "Device"
      Identifier "NVIDIA"
      Driver "nvidia"
      BusID "PCI:1:0:0"
    EndSection
  '';

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    open = false;
    nvidiaSettings = true;
    prime.nvidiaBusId = "PCI:1:0:0";
    package = pkgs.linuxKernel.packages.linux_6_6.nvidia_x11_legacy470;
  };

  nixpkgs.config.nvidia.acceptLicense = true;
  environment.sessionVariables = {
    NVD_BACKEND = "direct";
    LIBVA_DRIVER_NAME = "nvidia";
    MOZ_DISABLE_RDD_SANDBOX = "1";
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
  };
  environment.systemPackages = with pkgs; [ nvidia-container-toolkit nvtopPackages.full ];
}
