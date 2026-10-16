{
  hostName,
  lib,
  pkgs,
  config,
  ...
}:
lib.mkIf (hostName == "node4") {
  programs = {
    zsh.shellAliases.g = lib.getExe' pkgs.git "git";
    home.packages = with pkgs; [
      gnupg
      pinentry-tty
    ];
    direnv = {
      enable = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
    };
    git = {
      enable = true;

      settings = {
        user.name = "Zain Kergaye";
        user.email = "zain@zkergaye.me";

        signing = {
          format = "opengpg";
          signByDefault = true;
        };

        credential."https://git.duranaero.com" = {
          username = "zain.kergaye";
          helper = "cache";
        };

        commit.gpgSign = true;
        tag.gpgSign = true;
        core.whitespace = "error"; # Throw error on whitespace
        push.autoSetupRemote = true;
        pull.rebase = true;
        diff.colorMoved = "zebra";
        fetch.prune = true;

        advice = {
          # All advice messages disabled
          addEmptyPathspec = false;
          pushNonFastForward = false;
          statusHints = false;
        };

        status = {
          branch = true; # Show branch
          showStash = true;
          short = true;
        };

        alias = {
          st = "stage";
          s = "status";
          a = "add";
          c = "commit";
          ph = "push";
          pl = "pull";
          f = "fetch";
        };
      };
    };
  };
}
