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
