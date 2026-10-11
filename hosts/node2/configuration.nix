{ ... }: {
  imports = [
    ./hardware-configuration.nix
    ./gpu.nix
    ./security.nix
  ];

  # The ASUS host needs proprietary NVIDIA software, including the legacy
  # 470 driver selected in gpu.nix.
  nixpkgs.config.allowUnfree = true;

  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchDocked = "ignore";
    HandleLidSwitchExternalPower = "ignore";
  };

  lanNode = {
    enable = true;
    address = "10.10.10.12";
  };
}
