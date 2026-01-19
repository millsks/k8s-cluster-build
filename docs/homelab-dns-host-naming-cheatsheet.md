# Homelab DNS & Host Naming with Synology NAS (172.16.1.0/24, `home.arpa`)

This document describes how to:

1. Use a Synology NAS (DSM) as the DNS server for a homelab.  
2. Implement a Norse‑themed naming scheme for Kubernetes, Proxmox, storage, and services, **with role identifiers in hostnames**.  
3. Configure forward and reverse DNS zones for the `172.16.1.0/24` network and `home.arpa` domain.

## 1. Design Overview

- **Network:** `172.16.1.0/24`
- **Internal DNS domain:** `home.arpa`  
  - Standards‑friendly, reserved for private/home networks.
- **DNS server:** Synology NAS (DSM) running Synology’s **DNS Server** package.
- **Synology hostname/theme:** `ymir` (primordial giant, central storage + DNS).

### 1.1 Naming Pattern

Hostnames use Norse names plus **role identifiers** to make the purpose obvious at a glance:

**Role suffix conventions:**

- Kubernetes:
  - `-cp`  → control plane
  - `-wk`  → worker node
- Virtualization:
  - `-hv` → hypervisor (Proxmox)
- Storage:
  - `-nas` → primary NAS
  - `-bak` → backup / cold storage
- Infra / network:
  - `-dns` → DNS/infra services
  - `-rp`  → reverse proxy / ingress
- Applications:
  - `-sso`   → SSO / identity
  - `-media` → media server
  - `-wiki`  → documentation/wiki
- IoT / automation:
  - `-iot` → IoT / MQTT / HA

**FQDN patterns:**

- Kubernetes nodes: `name-role.cluster.home.arpa`
- Virtualization: `name-role.virtual.home.arpa`
- Storage: `name-role.storage.home.arpa`
- Network/infra: `name-role.net.home.arpa`
- Apps/portals: `name-role.apps.home.arpa`
- Media: `name-role.media.home.arpa`
- Docs: `name-role.docs.home.arpa`
- IoT: `name-role.iot.home.arpa`

## 2. IP Address Plan (172.16.1.0/24)

You can adjust this, but the following is a clean baseline.

### 2.1 Core Infra (DNS + Storage)

- `ymir-nas` – Synology DS925+ NAS (4x 14TB WD Red Pro drives) - DNS server + primary storage: `172.16.1.5`  
  → `ymir-nas.storage.home.arpa`

### 2.2 Kubernetes Cluster

All K8s nodes live under `*.cluster.home.arpa`:

- `odin-cp`   – K8s control plane: `172.16.1.201` (cluster), `192.168.86.201` (WiFi mgmt)  
  → `odin-cp.cluster.home.arpa`
- `huginn-wk` – worker node: `172.16.1.202` (cluster), `192.168.86.202` (WiFi mgmt)  
  → `huginn-wk.cluster.home.arpa`
- `muninn-wk` – worker node: `172.16.1.203` (cluster), `192.168.86.203` (WiFi mgmt)  
  → `muninn-wk.cluster.home.arpa`
- `freki-wk`  – worker node: `172.16.1.204` (cluster), `192.168.86.204` (WiFi mgmt)  
  → `freki-wk.cluster.home.arpa`
- `geri-wk`   – worker node: `172.16.1.205` (cluster), `192.168.86.205` (WiFi mgmt)  
  → `geri-wk.cluster.home.arpa`
- `sleipnir-wk` – worker node: `172.16.1.206` (cluster), `192.168.86.206` (WiFi mgmt)  
  → `sleipnir-wk.cluster.home.arpa`

### 2.3 Virtualization

- `heimdall-hv` – Proxmox server (hypervisor): `172.16.1.20`  
  → `heimdall-hv.virtual.home.arpa`

### 2.4 Additional Infra & Services (Optional / Reserved)

- `niflheim-bak` – backup / cold storage (NAS or VM): `172.16.1.30`  
  → `niflheim-bak.storage.home.arpa`
- `mimir-dns` – infra services VM (DNS helpers, etc.): `172.16.1.40`  
  → `mimir-dns.net.home.arpa`
- `gjallarhorn-rp` – reverse proxy / ingress / alerting: `172.16.1.41`  
  → `gjallarhorn-rp.net.home.arpa`
- `valhalla-sso` – SSO / main portal: `172.16.1.42`  
  → `valhalla-sso.apps.home.arpa`
- `idun-media` – media server (Plex/Jellyfin): `172.16.1.43`  
  → `idun-media.media.home.arpa`
- `saga-wiki` – documentation / wiki: `172.16.1.44`  
  → `saga-wiki.docs.home.arpa`
- `yggdrasil-iot` – IoT / MQTT / Home Assistant broker: `172.16.1.50`  
  → `yggdrasil-iot.iot.home.arpa`

> Note: You do not need to deploy all of these immediately; having them reserved in DNS is harmless and helps keep the scheme consistent.

## 3. Installing Synology DNS Server

1. Log in to the **DSM** web interface.
2. Open **Package Center**.
3. Search for **“DNS Server”** (official Synology package).
4. Click **Install**.
5. After installation, open **DNS Server** from the main menu.

Ensure your Synology NAS has a **static IP**: `172.16.1.5` (or your chosen address).

## 4. Create the Forward Zone (`home.arpa`)

1. Open **DNS Server** → **Zones** tab.
2. Under **Forward Zone**, click **Create** → **Master Zone**.
3. Configure:
   - **Domain type:** `Forward Zone`
   - **Domain name:** `home.arpa`
   - **Master DNS server:** your NAS hostname (e.g., `ymir-nas.storage.home.arpa` or whatever DSM suggests)
   - **Enable Zone:** checked.
4. Click **OK**.

This sets up the primary internal DNS zone for all hosts.

## 5. Add A Records (Forward Lookup)

In **DNS Server** → **Zones** → select `home.arpa` → **Edit** → **Resource Record**.  
Create the following **A** records (DSM automatically appends `.home.arpa` to the “Name” field):

| Name (DSM field)         | FQDN Created                           | IP Address      | Role                                  |
|--------------------------|----------------------------------------|-----------------|---------------------------------------|
| `odin-cp.cluster`        | `odin-cp.cluster.home.arpa`           | `172.16.1.201`  | K8s control plane                      |
| `huginn-wk.cluster`      | `huginn-wk.cluster.home.arpa`         | `172.16.1.202`  | K8s worker node                        |
| `muninn-wk.cluster`      | `muninn-wk.cluster.home.arpa`         | `172.16.1.203`  | K8s worker node                        |
| `freki-wk.cluster`       | `freki-wk.cluster.home.arpa`          | `172.16.1.204`  | K8s worker node                        |
| `geri-wk.cluster`        | `geri-wk.cluster.home.arpa`           | `172.16.1.205`  | K8s worker node                        |
| `sleipnir-wk.cluster`    | `sleipnir-wk.cluster.home.arpa`       | `172.16.1.206`  | K8s worker node                        |
| `heimdall-hv.virtual`    | `heimdall-hv.virtual.home.arpa`       | `172.16.1.20`   | Proxmox hypervisor                     |
| `ymir-nas.storage`       | `ymir-nas.storage.home.arpa`          | `172.16.1.5`    | Synology DS925+ NAS (4x 14TB WD Red Pro drives) - DNS + primary storage   |
| `niflheim-bak.storage`   | `niflheim-bak.storage.home.arpa`      | `172.16.1.30`   | Backup / cold storage                  |
| `mimir-dns.net`          | `mimir-dns.net.home.arpa`             | `172.16.1.40`   | Infra services VM (DNS helpers, etc.)  |
| `gjallarhorn-rp.net`     | `gjallarhorn-rp.net.home.arpa`        | `172.16.1.41`   | Reverse proxy / ingress / alerts       |
| `valhalla-sso.apps`      | `valhalla-sso.apps.home.arpa`         | `172.16.1.42`   | SSO / main portal                      |
| `idun-media.media`       | `idun-media.media.home.arpa`          | `172.16.1.43`   | Media server                           |
| `saga-wiki.docs`         | `saga-wiki.docs.home.arpa`            | `172.16.1.44`   | Wiki / docs                            |
| `yggdrasil-iot.iot`      | `yggdrasil-iot.iot.home.arpa`         | `172.16.1.50`   | IoT / MQTT / home automation           |

**How to add an A record in DSM:**

- Click **Create** → **A** record.
- **Name:** e.g., `odin-cp.cluster`
- **IP address:** e.g., `172.16.1.201`
- Leave TTL at default (e.g., 3600).
- Click **OK** or **Apply**.

Repeat this for each row in the table.

## 6. Create the Reverse Zone (`172.16.1.0/24`)

Reverse DNS allows lookups by IP → hostname, useful for some tools and logging.

1. In **DNS Server** → **Zones** tab, under **Reverse Zone**, click **Create** → **Master Zone**.
2. Configure:
   - **Network:** `172.16.1.0`
   - DSM will generate the appropriate reverse zone name: `1.16.172.in-addr.arpa`.
   - Ensure **Enable Zone** is checked.
3. Click **OK**.

## 7. Add PTR Records (Reverse Lookup)

With the reverse zone selected:

1. Click **Edit** → **Resource Record**.
2. Create **PTR** records for each host:

| Name (last octet) | PTR Target (FQDN, with trailing dot)       |
|-------------------|---------------------------------------------|
| `5`               | `ymir-nas.storage.home.arpa.`              |
| `20`              | `heimdall-hv.virtual.home.arpa.`           |
| `30`              | `niflheim-bak.storage.home.arpa.`          |
| `40`              | `mimir-dns.net.home.arpa.`                 |
| `41`              | `gjallarhorn-rp.net.home.arpa.`            |
| `42`              | `valhalla-sso.apps.home.arpa.`             |
| `43`              | `idun-media.media.home.arpa.`              |
| `44`              | `saga-wiki.docs.home.arpa.`                |
| `50`              | `yggdrasil-iot.iot.home.arpa.`             |
| `201`             | `odin-cp.cluster.home.arpa.`               |
| `202`             | `huginn-wk.cluster.home.arpa.`             |
| `203`             | `muninn-wk.cluster.home.arpa.`             |
| `204`             | `freki-wk.cluster.home.arpa.`              |
| `205`             | `geri-wk.cluster.home.arpa.`               |
| `206`             | `sleipnir-wk.cluster.home.arpa.`           |

**How to add a PTR record in DSM:**

- Click **Create** → **PTR** record.
- **Name:** e.g., `10`
- **PTR:** e.g., `odin-cp.cluster.home.arpa.`  
  (include the trailing dot for a fully qualified name, if DSM requires it)
- Click **OK**.

Repeat for each mapping.

## 8. Configure DNS Forwarders on Synology

The Synology DNS server should forward unknown domains (e.g., `google.com`) to public DNS resolvers.

1. Open **DNS Server** on DSM.
2. Go to the **Resolution** tab.
3. Enable **Forwarders**.
4. Add one or more upstream DNS servers, for example:
   - `1.1.1.1` (Cloudflare)
   - `8.8.8.8` (Google)
5. Click **Apply**.

Now, any query not in `home.arpa` is forwarded to the internet DNS.

## 9. Make Synology the DNS Server for the LAN

### Option A – via Router DHCP (recommended)

1. Log into your **router**’s admin UI.
2. Find the **LAN** / **DHCP** settings.
3. Set the **Primary DNS server** to the Synology NAS IP:
   - `172.16.1.5`
4. Optionally:
   - Leave **Secondary DNS** blank, or
   - Set it to another resolver (e.g., `1.1.1.1`).  
     If you want to *guarantee* internal DNS usage, you can omit secondary DNS and rely solely on Synology.
5. Save/apply settings.
6. On client devices, **renew DHCP leases** or reboot so they pick up the new DNS configuration.

### Option B – per host (manual)

If your router cannot set DNS via DHCP, manually configure each host (e.g., Linux, Windows, etc.) to use:

- **DNS server:** `172.16.1.5`

## 10. Verifying DNS Functionality

On any client that should be using the Synology DNS server:

**Check the resolver configuration:**

```bash
cat /etc/resolv.conf
```

Look for:

```text
nameserver 172.16.1.5
```

**Test forward lookups:**

```bash
ping odin-cp.cluster.home.arpa
ping heimdall-hv.virtual.home.arpa
```

Or using `dig` (if installed):

```bash
dig +short odin-cp.cluster.home.arpa
dig +short heimdall-hv.virtual.home.arpa
```

Expected results:

- `odin-cp.cluster.home.arpa` → `172.16.1.201`
- `heimdall-hv.virtual.home.arpa` → `172.16.1.20`

**Test reverse lookups:**

```bash
dig -x 172.16.1.201
dig -x 172.16.1.5
```

Expected results:

- `172.16.1.201` → `odin-cp.cluster.home.arpa`
- `172.16.1.5` → `ymir-nas.storage.home.arpa`

## 11. Summary Cheat Sheet

- **Domain:** `home.arpa`
- **Subnet:** `172.16.1.0/24` (cluster network), `192.168.86.0/24` (WiFi management)
- **Synology/DNS:** `ymir-nas.storage.home.arpa` → `172.16.1.5`
- **Key hosts:**
  - K8s control plane: `odin-cp.cluster.home.arpa` → `172.16.1.201` (cluster), `192.168.86.201` (WiFi)
  - K8s workers:
    - `huginn-wk.cluster.home.arpa` → `172.16.1.202` (cluster), `192.168.86.202` (WiFi)
    - `muninn-wk.cluster.home.arpa` → `172.16.1.203` (cluster), `192.168.86.203` (WiFi)
    - `freki-wk.cluster.home.arpa` → `172.16.1.204` (cluster), `192.168.86.204` (WiFi)
    - `geri-wk.cluster.home.arpa` → `172.16.1.205` (cluster), `192.168.86.205` (WiFi)
    - `sleipnir-wk.cluster.home.arpa` → `172.16.1.206` (cluster), `192.168.86.206` (WiFi)
  - Proxmox: `heimdall-hv.virtual.home.arpa` → `172.16.1.20`
  - Storage: `ymir-nas.storage.home.arpa`, `niflheim-bak.storage.home.arpa`
  - Infra/Apps/IoT:
    - `mimir-dns.net.home.arpa`
    - `gjallarhorn-rp.net.home.arpa`
    - `valhalla-sso.apps.home.arpa`
    - `idun-media.media.home.arpa`
    - `saga-wiki.docs.home.arpa`
    - `yggdrasil-iot.iot.home.arpa`

This structure gives you a coherent, extensible Norse‑themed naming scheme with clear role identifiers and proper internal DNS support, all anchored on your Synology NAS.
