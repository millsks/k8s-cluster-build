# Synology DNS Setup for Homelab (`home.arpa`, 172.16.0.0/24)

This document explains how to configure a Synology NAS (DSM) as the DNS server for the homelab, using:

- Network: `172.16.0.0/24`
- Internal DNS domain: `home.arpa`
- Norse‑themed hostnames with role identifiers, such as:
  - `odin-cp.cluster.home.arpa` (K8s control plane)
  - `heimdall-hv.virtual.home.arpa` (Proxmox hypervisor)
  - `ymir-nas.storage.home.arpa` (Synology NAS + DNS)

> For the full host naming scheme, see: **Homelab DNS & Host Naming with Synology NAS (172.16.0.0/24, `home.arpa`)**.

## 1. Prerequisites

- Synology NAS running DSM.
- Synology NAS has a **static IP** on the LAN, e.g.:  
  `ymir-nas` → `172.16.0.5`
- Homelab subnet: `172.16.0.0/24`.
- You have admin access to:
  - DSM (Synology web UI).
  - Your router’s DHCP settings (to point clients at Synology DNS).

## 2. Install the Synology DNS Server Package

1. Log in to **DSM**.
2. Open **Package Center**.
3. Search for **“DNS Server”**.
4. Click **Install**.
5. After installation, open **DNS Server** from the DSM main menu.

## 3. Create the Forward DNS Zone (`home.arpa`)

1. Open **DNS Server** → **Zones** tab.
2. Under **Forward Zone**, click **Create** → **Master Zone**.
3. Configure:
   - **Domain type:** `Forward Zone`
   - **Domain name:** `home.arpa`
   - **Master DNS server:** the Synology’s FQDN, e.g. `ymir-nas.storage.home.arpa` (or whatever DSM suggests).
   - Ensure **Enable Zone** is checked.
4. Click **OK**.

This defines the primary internal DNS namespace for the homelab.

## 4. Add A Records for Homelab Hosts

With the `home.arpa` forward zone created:

1. In **DNS Server**, go to **Zones**.
2. Select `home.arpa`, then click **Edit** → **Resource Record**.
3. Add the following **A** records.

> DSM automatically appends `.home.arpa` to the “Name” field.

### 4.1 Kubernetes Nodes (`*.cluster.home.arpa`)

| Name (DSM field)         | FQDN Created                           | IP Address      | Description        |
|--------------------------|----------------------------------------|-----------------|--------------------|
| `odin-cp.cluster`        | `odin-cp.cluster.home.arpa`           | `172.16.0.10`   | K8s control plane  |
| `huginn-w1.cluster`      | `huginn-w1.cluster.home.arpa`         | `172.16.0.11`   | K8s worker 1       |
| `muninn-w2.cluster`      | `muninn-w2.cluster.home.arpa`         | `172.16.0.12`   | K8s worker 2       |
| `geri-w3.cluster`        | `geri-w3.cluster.home.arpa`           | `172.16.0.13`   | K8s worker 3       |
| `freki-w4.cluster`       | `freki-w4.cluster.home.arpa`          | `172.16.0.14`   | K8s worker 4       |

### 4.2 Virtualization (`*.virtual.home.arpa`)

| Name (DSM field)         | FQDN Created                           | IP Address      | Description               |
|--------------------------|----------------------------------------|-----------------|---------------------------|
| `heimdall-hv.virtual`    | `heimdall-hv.virtual.home.arpa`       | `172.16.0.20`   | Proxmox hypervisor node   |

### 4.3 Storage (`*.storage.home.arpa`)

| Name (DSM field)         | FQDN Created                           | IP Address      | Description                        |
|--------------------------|----------------------------------------|-----------------|------------------------------------|
| `ymir-nas.storage`       | `ymir-nas.storage.home.arpa`          | `172.16.0.5`    | Synology NAS + DNS server          |
| `niflheim-bak.storage`   | `niflheim-bak.storage.home.arpa`      | `172.16.0.30`   | Backup / cold storage (future)     |

### 4.4 Infra / Network (`*.net.home.arpa`)

| Name (DSM field)         | FQDN Created                           | IP Address      | Description                          |
|--------------------------|----------------------------------------|-----------------|--------------------------------------|
| `mimir-dns.net`          | `mimir-dns.net.home.arpa`             | `172.16.0.40`   | Infra/DNS helper VM (optional)       |
| `gjallarhorn-rp.net`     | `gjallarhorn-rp.net.home.arpa`        | `172.16.0.41`   | Reverse proxy / ingress / alerting   |

### 4.5 Apps / Media / Docs / IoT

| Name (DSM field)         | FQDN Created                           | IP Address      | Description                |
|--------------------------|----------------------------------------|-----------------|----------------------------|
| `valhalla-sso.apps`      | `valhalla-sso.apps.home.arpa`         | `172.16.0.42`   | SSO / main portal (future) |
| `idun-media.media`       | `idun-media.media.home.arpa`          | `172.16.0.43`   | Media server               |
| `saga-wiki.docs`         | `saga-wiki.docs.home.arpa`            | `172.16.0.44`   | Wiki / documentation       |
| `yggdrasil-iot.iot`      | `yggdrasil-iot.iot.home.arpa`         | `172.16.0.50`   | IoT / MQTT / HA broker     |

#### How to add an A record in DSM

- Click **Create** → **A** record.
- **Name:** `odin-cp.cluster` (for example).
- **IP address:** `172.16.0.10`.
- Leave TTL at default.
- Click **OK** or **Apply**.
- Repeat for all entries above.

## 5. Create the Reverse DNS Zone (`172.16.0.0/24`)

Reverse DNS enables IP → hostname lookups.

1. In **DNS Server** → **Zones** tab.
2. Under **Reverse Zone**, click **Create** → **Master Zone**.
3. Configure:
   - **Network:** `172.16.0.0`
   - DSM will set the reverse zone name to: `0.16.172.in-addr.arpa`.
   - Ensure **Enable Zone** is checked.
4. Click **OK**.

## 6. Add PTR Records for Reverse Lookup

With the reverse zone created:

1. Select the `0.16.172.in-addr.arpa` reverse zone.
2. Click **Edit** → **Resource Record**.
3. Create **PTR** records for each host:

| Name (last octet) | PTR Target (FQDN with trailing dot)      |
|-------------------|-------------------------------------------|
| `5`               | `ymir-nas.storage.home.arpa.`            |
| `10`              | `odin-cp.cluster.home.arpa.`             |
| `11`              | `huginn-w1.cluster.home.arpa.`           |
| `12`              | `muninn-w2.cluster.home.arpa.`           |
| `13`              | `geri-w3.cluster.home.arpa.`             |
| `14`              | `freki-w4.cluster.home.arpa.`            |
| `20`              | `heimdall-hv.virtual.home.arpa.`         |
| `30`              | `niflheim-bak.storage.home.arpa.`        |
| `40`              | `mimir-dns.net.home.arpa.`               |
| `41`              | `gjallarhorn-rp.net.home.arpa.`          |
| `42`              | `valhalla-sso.apps.home.arpa.`           |
| `43`              | `idun-media.media.home.arpa.`            |
| `44`              | `saga-wiki.docs.home.arpa.`              |
| `50`              | `yggdrasil-iot.iot.home.arpa.`           |

#### How to add a PTR record in DSM

- Click **Create** → **PTR** record.
- **Name:** e.g. `10`.
- **PTR:** `odin-cp.cluster.home.arpa.`  
  (include the trailing dot if DSM expects absolute FQDNs).
- Click **OK**.
- Repeat for all entries.

## 7. Configure DNS Forwarders on Synology

The Synology DNS server should forward external queries (e.g. `google.com`) to public resolvers.

1. Open **DNS Server** on DSM.
2. Go to the **Resolution** tab.
3. Enable **Forwarders**.
4. Add upstream DNS servers, for example:
   - `1.1.1.1` (Cloudflare)
   - `8.8.8.8` (Google)
5. Click **Apply**.

Any domain not in `home.arpa` will now be forwarded upstream.

## 8. Point LAN Clients to Synology DNS

### Option A – via Router DHCP (recommended)

1. Log in to your **router**’s admin UI.
2. Go to **LAN** / **DHCP** settings.
3. Set **Primary DNS server** to the Synology NAS IP:
   - `172.16.0.5`
4. Optionally:
   - Leave **Secondary DNS** blank, or
   - Set a public resolver (e.g. `1.1.1.1`).  
     If you want to force internal resolution via Synology, you can skip the secondary DNS.
5. Save/apply.
6. On client devices, **renew DHCP leases** or reboot so they pick up the new DNS server.

### Option B – per Host (Manual)

On each host (if DHCP DNS settings can’t be changed):

- Set **DNS server** to: `172.16.0.5`.

## 9. Verify DNS Setup

On any client that should now be using Synology DNS:

### 9.1 Check Resolver Configuration

```bash
cat /etc/resolv.conf
```

You should see:

```text
nameserver 172.16.0.5
```

### 9.2 Test Forward Lookups

```bash
ping odin-cp.cluster.home.arpa
ping heimdall-hv.virtual.home.arpa
ping ymir-nas.storage.home.arpa
```

Or with `dig`:

```bash
dig +short odin-cp.cluster.home.arpa
dig +short heimdall-hv.virtual.home.arpa
dig +short ymir-nas.storage.home.arpa
```

Expected IPs:

- `odin-cp.cluster.home.arpa` → `172.16.0.10`
- `heimdall-hv.virtual.home.arpa` → `172.16.0.20`
- `ymir-nas.storage.home.arpa` → `172.16.0.5`

### 9.3 Test Reverse Lookups

```bash
dig -x 172.16.0.10
dig -x 172.16.0.5
```

Expected PTRs:

- `172.16.0.10` → `odin-cp.cluster.home.arpa`
- `172.16.0.5` → `ymir-nas.storage.home.arpa`

## 10. Example Usage in the Homelab

- SSH into the K8s control plane:

  ```bash
  ssh ubuntu@odin-cp.cluster.home.arpa
  ```

- Access the Proxmox web UI:

  ```text
  https://heimdall-hv.virtual.home.arpa:8006
  ```

- Future access to SSO portal:

  ```text
  https://valhalla-sso.apps.home.arpa
  ```

With this configuration:

- All homelab hosts use a consistent, Norse‑themed naming scheme.
- Role identifiers (`-cp`, `-w1`, `-hv`, `-nas`, `-rp`, etc.) make each host’s purpose clear at a glance.
- Synology (`ymir-nas`) provides centralized DNS for both internal services and external domains.
