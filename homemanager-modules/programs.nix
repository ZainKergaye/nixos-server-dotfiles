{
  inputs,
  pkgs,
  ...
}:
{
  programs.fastfetch.enable = true;
  home.packages = with pkgs; [
    inputs.nixvim-custom.packages."x86_64-linux".default
    git
    ripgrep
  ];
}
