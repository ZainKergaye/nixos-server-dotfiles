{ modulesPath, ... }: {
  networking.firewall = {
    enable = true;
  };
  adblock.enable = true;
  reverse_proxy.enable = true;
}
