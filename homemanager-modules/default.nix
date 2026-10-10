{
  config,
  inputs,
  lib,
  userName,
  ...
}:
{
  imports = [
    ./programs.nix
    ./shell.nix
    ./tmux.nix
  ];
  tmux-conf.enable = true;
  home.homeDirectory = "/home/${userName}";
  home.username = userName;

  home.stateVersion = "26.05";

  programs.btop = {
    enable = true;
    settings = {
      theme_background = false;
      vim_keys = true;
    };
  };

  programs.home-manager.enable = true;
}
