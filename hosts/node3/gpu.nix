{ ... }:
{
  # Both the GeForce GTX 1050 Ti and Tesla P4 use NVIDIA Pascal GPUs.  Newer
  # NVIDIA branches no longer support Pascal, so keep this host on the 580 LTSB
  # driver branch.  Pascal also requires the proprietary kernel module.
  hardware.graphics.enable = true;
  boot.blacklistedKernelModules = [ "nouveau" ];

  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    branch = "legacy_580";
    open = false;
    modesetting.enable = true;
    nvidiaSettings = false;
  };

  # Provides Docker CDI devices such as nvidia.com/gpu=0 for Immich ML.
  hardware.nvidia-container-toolkit.enable = true;
}
