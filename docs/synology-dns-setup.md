# DNS Setup for Homelab using Synology NAS

Below is a practical, step‑by‑step way to use your Synology NAS (DSM) as the DNS server for your homelab using a custom domain like `home.arpa` (or `home.lan` if you prefer).

I’ll assume:

- Your Synology has a **static IP** (e.g. `172.16.0.50`).
- Your router is doing **DHCP**.
- Your homelab nodes have (or will have) static or DHCP‑reserved IPs.

Adjust names/IPs as needed.


## 1. Choose Your Internal Domain

Pick one and stick with it:

- Recommended: `home.arpa`
- Alternative: `home.lan`

I’ll use `home.arpa` in the examples. If you prefer `home.lan`, just substitute it everywhere.

You’re planning hostnames like:

- `odin.cluster.home.arpa`
- `huginn.cluster.home.arpa`
- `muninn.cluster.home.arpa`
- `geri.cluster.home.arpa`
- `freki.cluster.home.arpa`
- `heimdall.virtual.home.arpa` (Proxmox)
- etc.

## 2. Install the DNS Server Package on Synology

1. Log in to DSM (the Synology web UI).
2. Open **Package Center**.
3. Search for **“DNS Server”** (official Synology package).
4. Click **Install**.
5. Once installed, open **DNS Server** from the main menu.

## 3. Create a Master Zone for `home.arpa`

1. In **DNS Server**, go to the **Zones** tab.
2. Under **Forward Zone**, click **Create** → **Master Zone**.
3. Fill in:
   - **Domain type**: `Forward Zone`
   - **Domain name**: `home.arpa`
   - **Master DNS server**: (your NAS hostname, e.g. `synology.home.arpa` or just `synology`). DSM may fill this automatically.
   - **Enable Zone**: checked.
4. Click **OK**.

You now have an internal DNS zone for `home.arpa`.

## 4. Add A Records for Your Nodes

With the `home.arpa` zone created, add the hosts.

1. In **DNS Server**, still in the **Zones** tab, select your `home.arpa` zone.
2. Click **Edit** → go to **Resource Record**.
3. Add **A records** for each node:

   For example, assuming these IPs:

   - `odin` (control plane): `172.16.0.10`
   - `huginn` (worker): `172.16.0.11`
   - `muninn` (worker): `172.16.0.12`
   - `geri` (worker): `172.16.0.13`
   - `freki` (worker): `172.16.0.14`
   - `heimdall` (Proxmox): `172.16.0.20`

   Click **Create** → **A Record** and fill in:

   - **Name**: `odin.cluster`
   - **TTL**: leave default (e.g. 3600)
   - **IP address**: `172.16.0.10`

   Repeat for each:

   - `huginn.cluster` → `172.16.0.11`
   - `muninn.cluster` → `172.16.0.12`
   - `geri.cluster` → `172.16.0.13`
   - `freki.cluster` → `172.16.0.14`
   - `heimdall.virtual` → `172.16.0.20`

   DSM will automatically append `.home.arpa` to the name, so the full FQDNs become:

   - `odin.cluster.home.arpa`
   - `huginn.cluster.home.arpa`
   - `muninn.cluster.home.arpa`
   - `geri.cluster.home.arpa`
   - `freki.cluster.home.arpa`
   - `heimdall.virtual.home.arpa`

4. Click **OK** or **Apply** to save.

## 5. (Optional But Recommended) Add Reverse Zone

This allows reverse DNS lookups (IP → name), which some tools like.

1. In **DNS Server** → **Zones** tab, under **Reverse Zone**, click **Create** → **Master Zone**.
2. Determine your network:

   If your LAN is `172.16.0.0/24`, the reverse zone name will be:

   - `1.168.192.in-addr.arpa`

3. Fill in:

   - **Domain type**: `Reverse Zone`
   - **Network**: `172.16.0.0`
   - DSM will set the correct reverse zone name.
4. Click **OK**.
5. Edit the reverse zone’s **Resource Record** and add **PTR records**:

   For each host:

   - **Name**: host’s last octet (e.g. `10` for `172.16.0.10`)
   - **PTR**: FQDN (e.g. `odin.cluster.home.arpa.`)

   Example:

   - `10` → `odin.cluster.home.arpa.`
   - `11` → `huginn.cluster.home.arpa.`
   - `12` → `muninn.cluster.home.arpa.`
   - `13` → `geri.cluster.home.arpa.`
   - `14` → `freki.cluster.home.arpa.`
   - `20` → `heimdall.virtual.home.arpa.`

   Make sure to end the FQDN with a dot in PTR records (`.home.arpa.`) if DSM requires it.

## 6. Configure Forwarders on Synology DNS

The Synology DNS should forward unknown domains (e.g. `google.com`) to public DNS servers.

1. In **DNS Server**, go to the **Resolution** tab.
2. Enable **Forwarders** (if not already).
3. Add one or more upstream DNS servers, for example:
   - `1.1.1.1` (Cloudflare)
   - `8.8.8.8` (Google)
4. Apply settings.

Now, anything not in `home.arpa` will be forwarded to the internet DNS.

## 7. Point Your Network to Use Synology as DNS

### Option A (Best): Use Router’s DHCP

1. Log into your **router’s admin UI**.
2. Find the **DHCP** settings (LAN/DHCP section).
3. Look for **DNS server** or **Primary DNS**.
4. Set **Primary DNS server** to your Synology IP, e.g.:

   - `172.16.0.50`

5. (Optional) Set a secondary DNS to something public (e.g. `1.1.1.1`) or leave blank if you want all internal resolution to always hit Synology.
6. Save/apply and **reboot or renew DHCP lease** on clients.

### Option B: Per‑Host DNS

If your router won’t let you change DNS servers via DHCP, then on each node/PC:

- Set **DNS server** to `172.16.0.50` manually in its network settings.

## 8. Verify Name Resolution

From any device that should now use Synology DNS (your laptop, a node, etc.):

1. Check that DNS is pointing to the Synology:

   ```bash
   cat /etc/resolv.conf
   ```

   You should see:

   ```text
   nameserver 172.16.0.50
   ```

2. Test name resolution:

   ```bash
   ping odin.cluster.home.arpa
   ping heimdall.virtual.home.arpa
   ```

3. On Linux, you can also use `dig` or `nslookup`:

   ```bash
   dig odin.cluster.home.arpa
   dig +short odin.cluster.home.arpa
   ```

   You should see `172.16.0.10` (or whatever you configured).

If these resolve correctly and respond to ping, your Synology DNS is working.

## 9. Sync with Your Host/IP Plan

Make sure:

- Each node (`odin`, `huginn`, etc.) really has the IPs you used in DNS.
- Ideally, configure them as **static IPs** or **DHCP reservations** in your router, so they never change.

## 10. Next Step: Use FQDNs in Your Homelab

Now you can:

- `ssh odin.cluster.home.arpa`
- Access Proxmox at `https://heimdall.virtual.home.arpa:8006`
- Use FQDNs in Kubernetes configs, Ansible inventories, etc.
