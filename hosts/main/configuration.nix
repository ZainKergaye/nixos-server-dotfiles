{ modulesPath, ... }: {
  networking.firewall = {
    enable = true;
  };
  networking.nameservers = [ "localhost" ];
  adblock.enable = true;
  reverse_proxy.enable = true;
  router = {
    enable = true;
    WANif = "enp1s0";
    LANif = "enp2s0";
  };
}
