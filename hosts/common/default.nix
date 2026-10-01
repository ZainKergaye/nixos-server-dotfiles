{
  lib,
  config,
  pkgs,
  modulesPath,
  ...
}:
{
  imports = [
    ./user.nix
    (modulesPath + "/virtualisation/qemu-vm.nix")
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  virtualisation.graphics = false;

  networking.firewall = {
    enable = true;
  };

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
  };

  programs.zsh = {
    enable = true;
  };

  nixpkgs = {
    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree packages
      allowUnfree = true;
    };
  };

  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      trusted-users = [ "@wheel" ];
      accept-flake-config = true;
    };
    channel.enable = false;

    package = pkgs.nixVersions.latest;
  };

  time.timeZone = "America/Denver";

  system.stateVersion = "26.11";
}
