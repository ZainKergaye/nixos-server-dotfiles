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
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCilF7srnwC/e/SE8uANIRiVL2MszMneqiqCO4bBujLCq42rgC+9ZKCjMIkLTsGP8SK/1+UFnn5GF0FaMuLb/JV9RALAW7/LbtEHKfN8HL1kZ+KO2+ziiDIv3nbwXao9AEqhejuuCIYuhQ+J9IS8iO/C1cyqHKxJcABWgrB2tNn9L/2tYfGnYkHdJHzlKU+N/jeSf2jdAIilSmJEVoU9wLW9cKAOIA7a0RJ3c8WEdPgrGkjxame6GuIIU9PjjcfxXgjiIQ9VUzdkPlW520nSVK2B/mi2IHNcfv8zLyKrr+KhNzPbSMsnfquVmuivJoAvsBAqWoGtWN0JPD0+XnCkDK7Nvnxk2cMWtJp17l6iDxy/wAt2Qz88iEx4j4kEQh4x6GiBsfiMEtcW+OqogvuDVIzzPT9fbx8W+auyeOrKMS5TsrZfGvsDhJEOTh+ViBxogG0nDZkhSzveXsHeHhM4hsBp+3V8bIuXtf5+kc97NQg9EPxt3gU1Q/Y91afOh8geLU= root@localhost"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPLheOhnlJTCn1sIj7emj2sdrZjHffO5/2WlEzwOp5lm khabib@nixos"
    ];
    extraGroups = [
      "wheel"
      "sudo"
    ];
  };
}
