# NixOS Server Dotfiles

Multi-host NixOS Dotfiles with deployment tools, secret management, reverse proxy, adblock, dns, metrics, and much more.

## Structure

The entrypoint is the flake. The flake pulls in the hostName at `hosts/xxx/configuration.nix`. Each host shares `hosts/common` but then individually takes any module it needs from `nixos-modules`. The `homemanager-modules` are hopefully the same across every machine.

## Features

- [ ] secret management
- [ ] deployment tools
- [ ] metrics

### main

#### Unattended installer USB

Build the self-installing ISO with:

```sh
nix build --impure path:.#main-installer --out-link main-installer.iso
```

Write `main-installer.iso` to a USB drive, boot it on `main`, and remove the
USB when it asks. The ISO automatically erases **only** `/dev/nvme0n1`, applies
the Disko layout, installs the prebuilt `main` system without requiring network
access, and reboots. Confirm the USB is booted on the intended machine before
using it: there is no interactive confirmation.

- [ ] openpfsense
- [x] vpn
- [x] reverse proxy
- [x] adblock
- [x] dns
- [ ] dashboard hosting
- [x] metrics
- [x] ups

### node1

- [x] immich
- [ ] jellyfin
- [ ] homebridge
- [ ] email server
- [x] security camera
- [x] ups

### node 2

nothing atm

### node 3

- [ ] AI workflows
- [ ] ups

### node 4

- [ ] dev workflow
- [ ] build server
- [ ] nix store cache (other nodes and main read from)
- [ ] ups
