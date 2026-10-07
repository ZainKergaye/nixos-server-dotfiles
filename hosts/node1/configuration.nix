{ ... }: {
  lanNode = {
    enable = true;
    address = "10.10.10.11";
  };
  prometheus.enable = true;
  ups.enable = true;
}
