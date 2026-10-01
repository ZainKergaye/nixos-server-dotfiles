# NixOS Server Dotfiles

Multi-host NixOS Dotfiles with deployment tools, secret management, reverse proxy, adblock, dns, metrics, and much more.

## Structure

The entrypoint is the flake. The flake pulls in the hostName at `hosts/xxx/configuration.nix`. Each host shares `hosts/common` but then individually takes any module it needs from `nixos-modules`. The `homemanager-modules` are hopefully the same across every machine.

## Features

- [ ] secret management
- [ ] deployment tools
- [ ] metrics

### main

- [ ] openpfsense
- [ ] vpn
- [ ] reverse proxy
- [ ] adblock
- [ ] dns
- [ ] dashboard hosting
- [ ] metrics

### node1

- [ ] immich
- [ ] jellyfin
- [ ] homebridge
- [ ] email server

### node 2

nothing atm

### node 3

- [ ] AI workflows

### node 4

- [ ] dev workflow
- [ ] build server
- [ ] nix store cache (other nodes and main read from)
