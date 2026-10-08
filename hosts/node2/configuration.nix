{ ... }: {
  lanNode = {
    enable = true;
    address = "10.10.10.12";
  };

  # Node 1 mounts this NFSv4 export and creates its Borg repository within it.
  services.nfs.server = {
    enable = true;
    exports = ''
      /srv/backups/immich 10.10.10.11(rw,sync,no_subtree_check,no_root_squash)
    '';
  };

  systemd.tmpfiles.rules = [
    "d /srv/backups/immich 0750 root root -"
  ];

  networking.firewall.extraCommands = ''
    iptables -A nixos-fw -p tcp --dport 2049 -s 10.10.10.11 -j ACCEPT
  '';
}
