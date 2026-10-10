{ inputs, ... }: {
  programs.fastfetch.enable = true;
  home.packages = [
    inputs.nixvim-custom.packages."x86_64-linux".default
  ];
}
