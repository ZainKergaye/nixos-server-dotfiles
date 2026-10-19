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
    #(modulesPath + "/virtualisation/qemu-vm.nix")
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  cominDeployment.enable = true;

  prometheus.enable = true;
  # All NUT participants decrypt the same monitor password locally. The
  # plaintext is only materialized at this runtime path by sops-nix.
  sops = {
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    secrets.ups-monitor-password = {
      sopsFile = ../../secrets/ups.yaml;
      mode = "0400";
    };
  };
  ups = {
    enable = true;
    passwordFile = config.sops.secrets.ups-monitor-password.path;
  };

  # virtualisation.graphics = false;

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

  nixpkgs.config.allowUnfree = false;

  nix = {
    optimise.automatic = true;
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
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
