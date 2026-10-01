{
  pkgs,
  config,
  userName,
  ...
}:
{
  users.users.${userName} = {
    isNormalUser = true;
    shell = pkgs.zsh;
    #initialHashedPassword = "${config.variables.initialHashedPassword}"; # TODO: Change this
    initialPassword = "test"; # WARN: DO NOT LEAVE IN SYSTEM
    openssh.authorizedKeys.keys = [
    ];
    extraGroups = [
      "wheel"
      "sudo"
    ];
  };
}
