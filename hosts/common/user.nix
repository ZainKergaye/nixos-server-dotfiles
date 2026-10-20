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
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPLheOhnlJTCn1sIj7emj2sdrZjHffO5/2WlEzwOp5lm khabib@nixos"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIFdO/G7+TxczZB6DzAnTzE1kNAsbvLMI9/vapvuuvpX zain@iMac"
      "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBC5tYsrfADZhFwuD3pa8Tik/kvJRsCW1clTK+YQJJ+JhJ5d/XsTT15M8sYbY8fCoxo1gD3fneqfAt/BV8rr4f2I="
    ];
    extraGroups = [
      "wheel"
      "sudo"
    ];
  };
}
