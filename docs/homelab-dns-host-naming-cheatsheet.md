# Homelab DNS & Host Naming with Synology NAS (172.16.0.0/24, `home.arpa`)

This document describes how to:

1. Use a Synology NAS (DSM) as the DNS server for a homelab.  
2. Implement a Norse‑themed naming scheme for Kubernetes, Proxmox, storage, and services.  
3. Configure forward and reverse DNS zones for the `172.16.0.0/24` network and `home.arpa` domain.

## 1. Design Overview

- **Network:** `172.16.0.0/24`
- **Internal DNS domain:** `home.arpa`  
  - Standards‑friendly, reserved for private/home networks.
- **DNS server:** Synology NAS (DSM) running Synology’s **DNS Server** package.
- **Synology hostname/theme:** `ymir` (primordial giant, central storage + DNS).

Naming pattern for FQDNs:

- Kubernetes nodes: `*.cluster.home.arpa`
- Virtualization (Proxmox): `*.virtual.home.arpa`
- Storage: `*.storage.home.arpa`
- Network/infra: `*.net.home.arpa`
- Apps/portals: `*.apps.home.arpa`
- Media: `*.media.home.arpa`
- Docs: `*.docs.home.arpa`
- IoT: `*.iot.home.arpa`

## 2. IP Address Plan (172.16.0.0/24)

You can adjust this, but the following is a clean baseline:

**Core infra (DNS + storage)**

- `ymir` – Synology NAS (DNS server + primary storage): `172.16.0.5`

**Kubernetes cluster**

- `odin` – K8s control plane: `172.16.0.10`
- `huginn` – worker node: `172.16.0.11`
- `muninn` – worker node: `172.16.0.12`
- `geri` – worker node: `172.16.0.13`
- `freki` – worker node: `172.16.0.14`

**Virtualization**

- `heimdall` – Proxmox server: `172.16.0.20`

**Additional infra & services (optional but pre‑reserved)**

- `niflheim` – backup / cold storage (NAS or VM): `172.16.0.30`
- `mimir` – infra services VM: `172.16.0.40`
- `gjallarhorn` – reverse proxy / ingress / alerting: `172.16.0.41`
- `valhalla` – SSO / main portal: `172.16.0.42`
- `idun` – media server (Plex/Jellyfin): `172.16.0.43`
- `saga` – documentation / wiki: `172.16.0.44`
- `yggdrasil` – IoT / MQTT / Home Assistant broker: `172.16.0.50`

> Note: You do not need to deploy all of these immediately; having them reserved in DNS is harmless and helps keep the scheme consistent.

## 3. Installing Synology DNS Server

1. Log in to the **DSM** web interface.
2. Open **Package Center**.
3. Search for **“DNS Server”** (official Synology package).
4. Click **Install**.
5. After installation, open **DNS Server** from the main menu.

Ensure your Synology NAS has a **static IP**: `172.16.0.5` (or your chosen address).

## 4. Create the Forward Zone (`home.arpa`)

1. Open **DNS Server** → **Zones** tab.
2. Under **Forward Zone**, click **Create** → **Master Zone**.
3. Configure:
   - **Domain type:** `Forward Zone`
   - **Domain name:** `home.arpa`
   - **Master DNS server:** your NAS hostname (e.g., `ymir.storage.home.arpa` or whatever DSM suggests)
   - **Enable Zone:** checked.
4. Click **OK**.

This sets up the primary internal DNS zone for all hosts.

## 5. Add A Records (Forward Lookup)

In **DNS Server** → **Zones** → select `home.arpa` → **Edit** → **Resource Record**.  
Create the following **A** records (DSM automatically appends `.home.arpa` to the “Name” field):

| Name (DSM field)     | FQDN Created                         | IP Address      | Role                                  |
|----------------------|--------------------------------------|-----------------|---------------------------------------|
| `odin.cluster`       | `odin.cluster.home.arpa`            | `172.16.0.10`   | K8s control plane                     |
| `huginn.cluster`     | `huginn.cluster.home.arpa`          | `172.16.0.11`   | K8s worker                            |
| `muninn.cluster`     | `muninn.cluster.home.arpa`          | `172.16.0.12`   | K8s worker                            |
| `geri.cluster`       | `geri.cluster.home.arpa`            | `172.16.0.13`   | K8s worker                            |
| `freki.cluster`      | `freki.cluster.home.arpa`           | `172.16.0.14`   | K8s worker                            |
| `heimdall.virtual`   | `heimdall.virtual.home.arpa`        | `172.16.0.20`   | Proxmox server                        |
| `ymir.storage`       | `ymir.storage.home.arpa`            | `172.16.0.5`    | Synology NAS (DNS + primary storage)  |
| `niflheim.storage`   | `niflheim.storage.home.arpa`        | `172.16.0.30`   | Backup / cold storage                 |
| `mimir.net`          | `mimir.net.home.arpa`               | `172.16.0.40`   | Infra services VM (DNS helpers, etc.) |
| `gjallarhorn.net`    | `gjallarhorn.net.home.arpa`         | `172.16.0.41`   | Reverse proxy / ingress / alerts      |
| `valhalla.apps`      | `valhalla.apps.home.arpa`           | `172.16.0.42`   | SSO / main portal                     |
| `idun.media`         | `idun.media.home.arpa`              | `172.16.0.43`   | Media server                          |
| `saga.docs`          | `saga.docs.home.arpa`               | `172.16.0.44`   | Wiki / docs                           |
| `yggdrasil.iot`      | `yggdrasil.iot.home.arpa`           | `172.16.0.50`   | IoT / MQTT / home automation          |

**How to add an A record in DSM:**

- Click **Create** → **A** record.
- **Name:** e.g., `odin.cluster`
- **IP address:** e.g., `172.16.0.10`
- Leave TTL at default (e.g., 3600).
- Click **OK** or **Apply**.

Repeat this for each row in the table.

## 6. Create the Reverse Zone (`172.16.0.0/24`)

Reverse DNS allows lookups by IP → hostname, useful for some tools and logging.

1. In **DNS Server** → **Zones** tab, under **Reverse Zone**, click **Create** → **Master Zone**.
2. Configure:
   - **Network:** `172.16.0.0`
   - DSM will generate the appropriate reverse zone name: `0.16.172.in-addr.arpa`.
   - Ensure **Enable Zone** is checked.
3. Click **OK**.

## 7. Add PTR Records (Reverse Lookup)

With the reverse zone selected:

1. Click **Edit** → **Resource Record**.
2. Create **PTR** records for each host:

| Name (last octet) | PTR Target (FQDN, with trailing dot)    |
|-------------------|------------------------------------------|
| `5`               | `ymir.storage.home.arpa.`               |
| `10`              | `odin.cluster.home.arpa.`               |
| `11`              | `huginn.cluster.home.arpa.`             |
| `12`              | `muninn.cluster.home.arpa.`             |
| `13`              | `geri.cluster.home.arpa.`               |
| `14`              | `freki.cluster.home.arpa.`              |
| `20`              | `heimdall.virtual.home.arpa.`           |
| `30`              | `niflheim.storage.home.arpa.`           |
| `40`              | `mimir.net.home.arpa.`                  |
| `41`              | `gjallarhorn.net.home.arpa.`            |
| `42`              | `valhalla.apps.home.arpa.`              |
| `43`              | `idun.media.home.arpa.`                 |
| `44`              | `saga.docs.home.arpa.`                  |
| `50`              | `yggdrasil.iot.home.arpa.`              |

**How to add a PTR record in DSM:**

- Click **Create** → **PTR** record.
- **Name:** e.g., `10`
- **PTR:** e.g., `odin.cluster.home.arpa.`  
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
   - `172.16.0.5`
4. Optionally:
   - Leave **Secondary DNS** blank, or
   - Set it to another resolver (e.g., `1.1.1.1`).  
     If you want to *guarantee* internal DNS usage, you can omit secondary DNS and rely solely on Synology.
5. Save/apply settings.
6. On client devices, **renew DHCP leases** or reboot so they pick up the new DNS configuration.

### Option B – per host (manual)

If your router cannot set DNS via DHCP, manually configure each host (e.g., Linux, Windows, etc.) to use:

- **DNS server:** `172.16.0.5`

## 10. Verifying DNS Functionality

On any client that should be using the Synology DNS server:

**Check the resolver configuration:**

```bash
cat /etc/resolv.conf
```

Look for:

```text
nameserver 172.16.0.5
```

**Test forward lookups:**

```bash
ping odin.cluster.home.arpa
ping heimdall.virtual.home.arpa
```

Or using `dig` (if installed):

```bash
dig +short odin.cluster.home.arpa
dig +short heimdall.virtual.home.arpa
```

Expected results:

- `odin.cluster.home.arpa` → `172.16.0.10`
- `heimdall.virtual.home.arpa` → `172.16.0.20`

**Test reverse lookups:**

```bash
dig -x 172.16.0.10
dig -x 172.16.0.5
```

Expected results:

- `172.16.0.10` → `odin.cluster.home.arpa`
- `172.16.0.5` → `ymir.storage.home.arpa`

## 11. Summary Cheat Sheet

- **Domain:** `home.arpa`
- **Subnet:** `172.16.0.0/24`
- **Synology/DNS:** `ymir.storage.home.arpa` → `172.16.0.5`
- **Key hosts:**
  - K8s control plane: `odin.cluster.home.arpa` → `172.16.0.10`
  - K8s workers: `huginn`, `muninn`, `geri`, `freki` under `cluster.home.arpa`
  - Proxmox: `heimdall.virtual.home.arpa` → `172.16.0.20`
  - Storage: `ymir.storage.home.arpa`, `niflheim.storage.home.arpa`
  - Infra/Apps/IoT: `mimir.net`, `gjallarhorn.net`, `valhalla.apps`, `idun.media`, `saga.docs`, `yggdrasil.iot`

This structure gives you a coherent, extensible Norse‑themed naming scheme with proper internal DNS support, all anchored on your Synology NAS.
