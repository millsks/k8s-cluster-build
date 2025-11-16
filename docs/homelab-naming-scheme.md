# Homelab Naming Schema

## 1. Core Kubernetes Cluster

You already have:

- Control plane:
  - `odin`
- Worker nodes:
  - `huginn`
  - `muninn`
  - `geri`
  - `freki`

That’s a great start. I’d keep those as your primary K8s nodes.

If you add more workers later:

- Additional general workers:
  - `vidar`, `vali` (children of Odin)
  - `bragi` (poet, could be “logging/metrics” node)
  - `tyr` (battle god, could be for “high-load” node)

Example FQDNs:

- `odin.cluster.home.arpa`
- `huginn.cluster.home.arpa`
- `muninn.cluster.home.arpa`
- `geri.cluster.home.arpa`
- `freki.cluster.home.arpa`

## 2. Proxmox / Virtualization Layer

Primary Proxmox node (as you suggested):

- `heimdall` – the vigilant guardian (perfect for Proxmox)

If you ever do a Proxmox cluster:

- `heimdall` – main/first node
- `bifrost` – second node (bridge of the gods)
- `asgardi` – third node (Asgard infrastructure host)
- `gjallarhorn` – a node dedicated to monitoring/alerting VMs

Example FQDNs:

- `heimdall.virtual.home.arpa`
- `bifrost.virtual.home.arpa`
- `asgardi.virtual.home.arpa`

## 3. Network / Edge / Infrastructure

Routers, firewalls, VPN, DNS, etc.:

- **Edge router / main firewall**: `bifrost`  
  (if you don’t use it for Proxmox) – the bridge between worlds/your LAN ↔ internet.
- **Alternative firewall / backup router**: `skidbladnir`  
  (Frey’s ship that can be folded up, nice metaphor for flexible networking)
- **VPN gateway**: `heimdall` or `gjallarbrú` (if Heimdall is already Proxmox)
- **DNS / DHCP server**: `mimir`  
  (wise being, keeper of knowledge – great for “where is what” service)
- **Reverse proxy / ingress**: `bifrost` or `gjallarhorn`  
  (announces & routes the “coming of the gods” = your web services)

Example:

- `bifrost.net.home.arpa` (router/firewall)
- `mimir.net.home.arpa` (DNS/DHCP)
- `gjallarhorn.net.home.arpa` (reverse proxy / ingress)

## 4. Storage & Backup

Storage servers, NAS, backup boxes:

- Primary NAS / storage server: `ymir`  
  (primordial giant from which the world is made – central data)
- Backup NAS: `niflheim`  
  (cold, dark realm – good for “cold storage” backups)
- Off-site / external backup (if you ever name it): `hel`  
  (realm of the dead – where “old data” goes, a bit dark but memorable)

Example:

- `ymir.storage.home.arpa`
- `niflheim.storage.home.arpa`
- `hel.storage.home.arpa`

## 5. Platform Services (Running on K8s or VMs)

Logical services can also follow the theme.

### Monitoring / Logging / Metrics

- Monitoring stack (Prometheus/Grafana/whatever):
  - `heimdallr` (alt spelling) or `hodr` (if not used elsewhere)
- Centralized logs (ELK/Loki/etc.):
  - `skuld` (one of the Norns; she decides the future = events)
- Alertmanager / notification hub:
  - `gjallarhorn` (the horn Heimdall blows at Ragnarok)

Example:

- `monitoring.asgard.home.arpa`
- `skuld.asgard.home.arpa`
- `gjallarhorn.asgard.home.arpa`

### CI/CD / Build / Automation

- CI server (Jenkins, GitLab Runner, etc.): `dvalin` (a dwarf, “craftsman”)
- Automation / orchestrator (Ansible AWX, etc.): `ullr` (god of craft and skill)
- Artifact registry (Harbor/registry): `brokkr` or `sindri` (legendary smiths)

Example:

- `dvalin.dev.home.arpa`
- `ullr.dev.home.arpa`
- `brokkr.dev.home.arpa`

## 6. User-Facing / Apps / Dashboards

Web UIs, media, docs, etc.:

- Main SSO/portal (if you ever run Keycloak/Authelia): `valhalla`  
  (central “hall” for identities and logins)
- Application dashboard (if you use Heimdall app *as a service*):
  - Don’t call this one `heimdall` to avoid confusion with the Proxmox host.
  - Use: `bifrost-app`, `asgard-portal`, or `valhalla-portal`
- Media server (Plex/Jellyfin/etc.): `idun` or `idunn`  
  (goddess of youth/apples – “refreshing” media)
- Docs/wiki: `frigg` (Odin’s wife, associated with wisdom) or `saga`  
  (literally: stories)

Example:

- `valhalla.apps.home.arpa` (SSO portal)
- `asgard-portal.apps.home.arpa` (dashboard)
- `idun.media.home.arpa` (Plex/Jellyfin)
- `saga.docs.home.arpa` (wiki/docs)

## 7. IoT / Smart Home / Misc

If you extend the theme to IoT, home automation, etc.:

- Home automation (Home Assistant, etc.): `freya` or `freyja`
- Networked sensors/hub: `yggdrasil`  
  (world tree connecting everything – neat for MQTT or a central hub)
- Camera NVR/recording server: `hodr`  
  (some irony: blind god; or pick `baldr` instead)

Example:

- `freya.house.home.arpa`
- `yggdrasil.iot.home.arpa`
- `baldr.cctv.home.arpa`

## 8. How to Keep It Organized

One simple pattern:

- Use subdomains by function:
  - `cluster.home.arpa` – Kubernetes nodes
  - `virtual.home.arpa` – Proxmox/virtualization
  - `net.home.arpa` – routers, DNS, ingress
  - `storage.home.arpa` – NAS and backup
  - `apps.home.arpa` – app frontends
  - `dev.home.arpa` – CI/CD/registry
  - `iot.home.arpa`, `house.home.arpa` – smart home stuff

This makes it easy to:

- Keep the Norse names fun and memorable.
- Still instantly know what category a host belongs to from the FQDN.
