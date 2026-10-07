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
