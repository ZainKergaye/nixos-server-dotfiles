{ inputs, ... }: {
  programs.fastfetch.enable = true;
  home.packages = [
    inputs.nixvim-custom.packages.${stdenv.hostPlatform.system}.default
  ];
}
