{
  config,
  lib,
  pkgs,
  hostName,
  userName,
  ...
}:
let
  dotfilesDir = "/home/${userName}/.dotfiles";
  myAliases = {
    la = "ls -la";
    upgrade = lib.getExe (
      pkgs.writeShellScriptBin "upgrade" ''
        sudo nixos-rebuild switch --flake ${dotfilesDir}/.#${hostName}
      ''
    );
    neofetch = "fastfetch";
    t = "${lib.getExe' pkgs.trashy "trash"}";
    rm = lib.getExe (
      pkgs.writeShellScriptBin "rm-confirmation" ''
        read -r -p "Really run rm? Type 'yes' to continue: " ans
        if [[ "$ans" != "yes" ]]; then
          echo "Aborted."
          exit 1
        fi
        exec ${lib.getExe' pkgs.coreutils "rm"} "$@"
      ''
    );
  };
in
{
  home.packages = with pkgs; [
    zoxide
    trashy
  ];
  programs = {
    zoxide = {
      enable = true;
      enableZshIntegration = true;
    };
    bash = {
      enable = lib.mkDefault false; # Forces bash to be disabled unless some other file enables it
      shellAliases = myAliases;
    };

    zsh = {
      enable = true;
      shellAliases = myAliases;

      oh-my-zsh = {
        enable = true;
        theme = "miloshadzic";
        plugins = [
          "sudo"
          "colored-man-pages"
        ];
      };
      syntaxHighlighting.enable = true;
    };
  };
}
