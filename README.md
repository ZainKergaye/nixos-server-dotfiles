# NixOS Server Dotfiles

Multi-host NixOS Dotfiles with deployment tools, secret management, reverse proxy, adblock, dns, metrics, and much more.

## Updates and build verification

The workflows in `.github/workflows` follow the setup in
[nixosdotfiles](https://github.com/ZainKergaye/nixosdotfiles/tree/master/.github/workflows)
and [nixvim_dotfiles](https://github.com/ZainKergaye/nixvim_dotfiles/tree/master/.github/workflows).

- **Build** runs on pull requests, pushes to `master`, and manual dispatch. It
  evaluates all flake outputs, including both installer configurations, then
  builds the NixOS systems for `main`, `node1`, `node2`, `node3`, and `node4`.
  Installer ISO images and VM images are evaluated but are not built by CI.
- **Update Flake Inputs** runs Sundays and Wednesdays at 02:00 UTC, or manually
  from the Actions tab. It updates `flake.lock`, runs the same verification,
  and opens or updates `chore/flake-update` with a revision summary only after
  verification passes. Failed builds leave the default branch unchanged.
  Updates require review and merge; the workflow does not enable auto-merge.
- Both workflows use `zain-system-cache` on Cachix. Pull requests without a
  cache token can still read the public cache.

Before enabling scheduled updates, install the existing flake-update GitHub App
on this repository with **Contents**, **Issues**, and **Pull requests** write
permissions. Configure these repository Actions secrets (or grant this repository
access to equivalent organization secrets):

| Secret | Value |
| --- | --- |
| `APP_ID` | The flake-update GitHub App ID |
| `FLAKE_UPDATE_PRIVATE_KEY` | The App's PEM private key |
| `CACHIX_AUTH_TOKEN` | A token with write access to `zain-system-cache` |

App tokens are scoped to this repository and refreshed before the build and
before PR creation. Using an App token allows update PRs to trigger the Build
workflow. The schedule becomes active once the workflows are on `master`.
To enforce verification before any merge, require the `build` status check in
the branch protection rules for `master`.

Run the checks locally with:

```sh
python3 -m unittest discover -s .github/scripts -p 'test_*.py'
nix flake check --accept-flake-config --no-build --no-update-lock-file
for host in main node1 node2 node3 node4; do
  nix build ".#nixosConfigurations.$host.config.system.build.toplevel" \
    --accept-flake-config --no-link --no-update-lock-file --show-trace || exit 1
done
```

## Structure

System and container logs from every node are available in Grafana's
**Infrastructure → Homelab Logs** dashboard. See [Central logs](docs/central-logs.md)
for filters, queries, retention, and deployment verification.

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

#### Unattended installer USB

Build the self-installing ISO with:

```sh
nix build --impure path:.#node1-installer --out-link node1-installer.iso
```

Write `node1-installer.iso` to a USB drive, boot it on `node1`, and remove the
USB when it asks. The ISO automatically erases **only** `/dev/nvme0n1`, applies
the Disko layout, installs the prebuilt `node1` system without requiring network
access, and reboots. Confirm the USB is booted on the intended machine before
using it: there is no interactive confirmation.

- [x] immich
- [ ] jellyfin
- [x] homebridge
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
