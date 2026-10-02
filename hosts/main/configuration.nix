{ modulesPath, ... }: {
  networking.firewall = {
    enable = true;
  };
  networking.nameservers = [ "localhost" ];
  adblock.enable = true;
  reverse_proxy.enable = true;
}
