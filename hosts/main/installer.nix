{
  lib,
  mainDiskoScript,
  mainSystem,
  modulesPath,
  pkgs,
  ...
}:
{
  imports = [ (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix") ];

  networking.hostName = "main-installer";

  # Keep the ISO self-contained: the installer receives the pre-evaluated
  # Disko script and the complete main system closure from flake.nix.
  system.extraDependencies = [ mainDiskoScript mainSystem ];

  systemd.services.install-main = {
    description = "Unattended installation of main onto /dev/nvme0n1";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];
    before = [ "getty@tty1.service" ];
    path = [
      pkgs.coreutils
      pkgs.systemd
      pkgs.util-linux
    ];
    serviceConfig = {
      Type = "oneshot";
      StandardOutput = "journal+console";
      StandardError = "journal+console";
    };
    script = ''
      set -euo pipefail

      target=/dev/nvme0n1
      if ! test -b "$target"; then
        echo "Refusing installation: expected target disk $target is absent." >&2
        exit 1
      fi

      echo "Installing main to $target; all existing data on that disk will be erased."
      ${mainDiskoScript}
      nixos-install --root /mnt --system ${mainSystem} --no-root-passwd
      sync
      echo "Installation complete; rebooting in 10 seconds. Remove the USB drive."
      sleep 10
      systemctl reboot --force
    '';
  };

  image = {
    fileName = "main-installer.iso";
  };

  isoImage = {
    squashfsCompression = "zstd -Xcompression-level 6";
  };
}
