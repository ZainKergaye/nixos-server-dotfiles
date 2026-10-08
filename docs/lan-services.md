# LAN service template

`main` is the LAN router, DNS resolver, and HTTP reverse proxy.  The node
addresses are intentionally static:

| Host | Address | Direct DNS name |
| --- | --- | --- |
| main | `10.10.10.1` | `main.home` |
| node1 | `10.10.10.11` | `node1.home` |
| node2 | `10.10.10.12` | `node2.home` |
| node3 | `10.10.10.13` | `node3.home` |
| node4 | `10.10.10.14` | `node4.home` |

## Adding a web service

Add a hostname-to-upstream route under `reverse_proxy.routes` in
`hosts/main/configuration.nix`:

```nix
reverse_proxy.routes = {
  "immich.home" = "10.10.10.11:2283";
  "jellyfin.home" = "10.10.10.11:8096";
  # "service.home" = "10.10.10.12:PORT";
};
```

After rebuilding `main`, Blocky resolves each service name to `10.10.10.1`
and Caddy forwards the HTTP request to its assigned node and port.  The direct
node names still resolve to their respective node addresses.

Caddy listens only on `10.10.10.1`, and the firewall permits port 80 only from
`10.10.10.0/24`; these routes are therefore unavailable from the WAN.  This
template is HTTP-only by design.  Add internal TLS later only after deciding
how clients will trust Caddy's local CA.

## Monitoring

Every host runs the Prometheus node exporter on port `9100`.  Its firewall rule
only permits the collector on `main` (`10.10.10.1`).  `main` runs the single
Prometheus server and Grafana; Grafana uses the local Prometheus datasource, so
all hosts are available from one dashboard.  Grafana listens on port `3000`.
Use `http://grafana.home` from the LAN; Caddy exposes it through the existing
LAN-only reverse proxy rule.

To add a metrics-capable service, expose its Prometheus endpoint, append a
scrape job in `nixos-modules/prometheus/default.nix`, and contribute its JSON
dashboard through `grafana.dashboards`.  The dashboard is then provisioned
automatically on `main`.

## Scrypted and HomeKit Secure Video

`node1` runs Scrypted at `http://scrypted.home`; its direct HTTPS endpoint is
also available at `https://10.10.10.11:10443` with a self-signed certificate.
Scrypted is intentionally reachable without its own login, but the Node 1
firewall accepts it (including HomeKit's mDNS and dynamic accessory ports) only
from `10.10.10.0/24` and connected WireGuard clients (`10.100.0.0/24`). It is
not available from the WAN.

The Scrypted container retains only its configuration, plugins, and HomeKit
pairings in `/var/lib/scrypted`. It has no `/nvr` mount and no NVR recording
storage configured, so it does not retain camera footage. Do not install or
enable the Scrypted NVR plugin. With a HomePod or Apple TV hub, HomeKit Secure
Video uploads the recordings to Apple instead.

After deploying Node 1, add the camera in the Scrypted management console:

1. Install the `RTSP` plugin (or the Amcrest plugin if the specific Lorex model
   is supported), then add the Lorex camera using its `rtsp://...` URL.
2. Assign both the main stream and substream when the camera offers them; use
   the lower-resolution substream for motion analysis.
3. Install and enable the `HomeKit` plugin for the camera, scan that camera's
   pairing QR code in Apple Home, then select **Stream & Allow Recording**.

The Lorex RTSP IP/URL is deliberately not committed here: it is camera-specific
and commonly embeds credentials. Keep it in Scrypted's local configuration
rather than Git.

## Immich

`node1` runs authenticated Immich at `http://immich.home` on the LAN and
directly at `http://10.10.10.11:2283` from connected WireGuard clients. The
service is not exposed on the WAN. Register the first account through the
**Getting Started** page; that account becomes the administrator. Do not
disable Immich authentication.

Immich stores originals, generated thumbnails/transcodes, and its automatic
database dumps below `/var/lib/immich`. Node 1 mounts the NFSv4 export
`10.10.10.12:/srv/backups/immich` on demand and runs Borg daily at 03:30,
retaining 7 daily, 4 weekly, and 12 monthly archives. The repository is
initialized automatically at `/mnt/immich-backup/borg`; Node 2 permits NFSv4
only from Node 1. Both the NFS server and export path are configurable through
`immich.backup.nfsServer` and `immich.backup.nfsExport`.

The default Borg mode is unencrypted because the dedicated NFS server is on the
trusted LAN. To encrypt archives, set `immich.backup.borgEncryptionMode` and
provide `immich.backup.borgPassCommand` pointing to a separately provisioned
secret file; never place the passphrase in Git.

### Initial 30 GB import

Upload from the computer that currently holds the library rather than copying
files into `/var/lib/immich`. After creating an API key in **Account Settings →
API Keys**, run the current Immich CLI on that computer:

```sh
npm install -g @immich/cli
immich login http://10.10.10.11:2283/api YOUR_API_KEY
immich upload --dry-run --recursive /path/to/photo-library
immich upload --recursive /path/to/photo-library
```

Use the Node 1 address over WireGuard when importing remotely. The CLI hashes
files and Immich deduplicates them, so retries are safe; keep the source copy
until the import and off-node backup have both been verified.

## UPS shutdown coordination

The USB-connected CyberPower CP1500C is served by NUT on `main`. Every node
runs a NUT secondary monitor, so a low-battery or forced-shutdown event causes
each protected host to shut down cleanly. NUT port `3493` is LAN-only; its
Prometheus exporter is local to `main`.

Before deploying, create one strong shared password on `main`:

```sh
sudo install -d -m 0700 /etc/nut
openssl rand -base64 32 | sudo tee /etc/nut/ups-monitor-password >/dev/null
sudo chmod 0600 /etc/nut/ups-monitor-password
```

Copy that exact file to `node1` through `node4` using your normal secure admin
path; it is deliberately not stored in this repository. Deploy `main` first,
then the clients. On `main`, run `upsc UPS-1@localhost`; it should report
`ups.status: OL` while utility power is present.

## Router monitoring and logs

The router's node exporter feeds the **Router Overview** Grafana dashboard with
LAN/WAN traffic, interface errors and drops, conntrack use, uptime, and the
state of DNS/DHCP/proxy services. The router also retains its journal for up to
30 days (or 1 GiB). Refused inbound TCP connection attempts are recorded in
the kernel journal without enabling noisy per-packet logging:

```sh
sudo journalctl -k -g 'refused connection' --since today
sudo journalctl -u dnsmasq -u blocky --since today
```

## Intrusion detection

Suricata runs in IDS mode on the router WAN interface. It inspects inbound and
outbound Internet traffic with the maintained Suricata rule sources, including
known command-and-control and malware indicators. It does **not** drop traffic
inline; detection is safer for the current router because a false positive
cannot break a client connection. Rules update daily and Suricata reloads them
automatically.

Inspect concise alerts and structured events on `main` with:

```sh
sudo tail -F /var/log/suricata/fast.log
sudo journalctl -u suricata -u suricata-update --since today
```

The Router Overview dashboard includes Suricata's service health. Add inline
IPS blocking only after reviewing alerts and selecting a conservative allow/
drop policy for this network.

## Remote access with WireGuard

`main` provides a full-tunnel WireGuard gateway on UDP port `51820`. VPN
clients receive an address in `10.100.0.0/24`, can reach `main` and every
`10.10.10.0/24` LAN node, and send Internet traffic through the router's WAN
NAT. The server key is generated at `/var/lib/wireguard/server.key`; it is not
stored in Git.

Add each outside device to `wireguardGateway.peers` in
`hosts/main/configuration.nix`, with its generated public key and a unique
address such as `10.100.0.2/32`. After deploying `main`, obtain the server
public key with `sudo wg show wg0 public-key`. A full-tunnel client profile
uses `AllowedIPs = 0.0.0.0/0`, `DNS = 10.10.10.1`, and endpoint
`<your-public-DNS-or-IP>:51820`.

If the WAN is behind another ISP router, forward UDP port `51820` to `main`.
Check a connected client with `sudo wg show` on `main`; it should show a recent
handshake and transfer counters.

WireGuard peer metrics are collected locally by Prometheus and shown in the
**WireGuard Overview** Grafana dashboard: configured-peer count, time since
each peer's latest handshake, and per-peer upload/download rates. The exporter
only listens on `127.0.0.1:9586`.

## Continuous deployment with Comin

Every host runs Comin in pull mode. It polls the repository's `main` branch
every 60 seconds and deploys the matching `nixosConfigurations.<hostname>`
output. Comin retains recent successful and bootable deployments, so a failed
commit does not replace the current system. Its Prometheus exporter is exposed
only to the central collector on port `4243`; Grafana provisions a **Comin
Deployments** dashboard for exporter health.

The configured repository URL is the public HTTPS GitHub URL. If this
repository is private, override `cominDeployment.repository` with an
authenticated transport and provision its credentials on every host before
enabling Comin.
