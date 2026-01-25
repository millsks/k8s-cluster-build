### Synology DS925+ (DSM) Active Directory + Linux Node Configuration (cluster.home.arpa)

This runbook walks you through:

1. Configuring your Synology NAS (DS925+) as an **Active Directory Domain Controller** using **Synology Directory Server** (Samba-based AD DC)
2. Configuring Linux (Kubernetes) nodes to authenticate against that AD domain using **realmd + SSSD**

It is written to be copy/paste friendly and repeatable across multiple nodes.

#### Assumptions / placeholders (edit to match your environment)

- **AD domain (DNS name):** `cluster.home.arpa`
- **Kerberos realm:** `CLUSTER.HOME.ARPA`
- **Synology hostname (AD DC):** `ymir.cluster.home.arpa`
- **Synology IP (AD DNS/DC):** `172.16.1.221`
- **NFS homes export (optional):** `/volume3/homes`
- **Linux home mountpoint (optional):** `/mnt/homes`

If you already have different values, replace them consistently everywhere.

---

### Part 1 — DSM: Configure Active Directory on Synology (Directory Server)

#### 1.1 Install Synology Directory Server

1. In DSM, open **Package Center**.
2. Install **Directory Server**.
3. Launch **Directory Server**.

#### 1.2 Create a new AD domain

1. In **Directory Server**, choose **Set up a new domain**.
2. Set:
   - **Domain name (FQDN):** `cluster.home.arpa`
   - **NetBIOS name:** pick a short name such as `CLUSTER`
   - **Administrator password:** set and record securely
3. Complete the wizard.

What this does:
- Your Synology becomes an **AD DC** (Samba AD)
- It provides **Kerberos**, **LDAP**, and AD services

#### 1.3 DNS requirements (critical)

AD authentication depends on correct DNS (including SRV records).

You should ensure that Linux nodes use the Synology DC as their DNS server (at least for the cluster network).

On a Linux node, you should later be able to run:

```bash
host -t SRV _kerberos._udp.cluster.home.arpa
```

and get a valid response.

#### 1.4 Create AD users and groups (Directory Server)

Important: DSM has **local users** and **AD users**. For Linux AD logins, you must create users in **Directory Server → Users**.

1. Open **Directory Server**.
2. Go to **Users** → **Create**.
3. Create your user(s), e.g. `millsks`.
4. (Recommended) Create groups such as:
   - `k8s-admins`
   - `k8s-users`
   and add users to them.

#### 1.5 (Optional) Enable / configure NFS homes on Synology

If you want **centralized home directories** for AD users (recommended for consistency across nodes), configure an NFS export.

1. Create or pick a shared folder for homes (example export path): `/volume3/homes`
2. DSM → **Control Panel** → **File Services** → enable **NFS**.
3. Set NFS permissions for the shared folder:
   - Prefer granting access by **subnet** (e.g., `172.16.1.0/24`) rather than hostname wildcards.
   - Mapping/squash: typically **No mapping** (depends on your security requirements).

---

### Part 2 — Linux nodes: Join to Synology AD (realmd + SSSD)

Perform these steps on **each** Linux node (control plane and workers).

#### 2.1 Install packages

Ubuntu/Debian:

```bash
sudo apt update
sudo apt install -y realmd sssd sssd-tools adcli samba-common-bin \
  libnss-sss libpam-sss krb5-user
```

If you are also mounting NFS homes:

```bash
sudo apt install -y nfs-common
```

#### 2.2 Ensure the node uses Synology for DNS (for AD)

Check DNS:

```bash
resolvectl status
```

You want the primary cluster interface to use:
- DNS: `172.16.1.221`
- Search domain includes: `cluster.home.arpa`

Then verify Kerberos SRV discovery:

```bash
host -t SRV _kerberos._udp.cluster.home.arpa
```

If SRV lookup fails, fix DNS first. AD will not work reliably without it.

#### 2.3 Join the node to the domain

Discover the domain:

```bash
sudo realm discover cluster.home.arpa
```

Join:

```bash
sudo realm join cluster.home.arpa -U Administrator
```

Verify:

```bash
realm list
```

You should see `configured: kerberos-member` and `client-software: sssd`.

#### 2.4 Configure SSSD

Create/overwrite `/etc/sssd/sssd.conf`:

```ini
[sssd]
config_file_version = 2
services = nss, pam
domains = cluster.home.arpa

[domain/cluster.home.arpa]
id_provider = ad
ad_domain = cluster.home.arpa
krb5_realm = CLUSTER.HOME.ARPA

cache_credentials = True

# Allow all for initial bring-up. (You can restrict later.)
access_provider = simple

# Prefer simple logins like 'millsks' instead of 'millsks@cluster.home.arpa'
use_fully_qualified_names = False

# Home directory behavior
fallback_homedir = /home/%u
# If using NFS homes mounted at /mnt/homes, use:
# fallback_homedir = /mnt/homes/%u

default_shell = /bin/bash

enumerate = False

# Synology AD environments can map UIDs to large values. Avoid "uid out of range".
ldap_id_mapping = True
min_id = 1000
max_id = 2000000000
```

Lock down permissions and restart:

```bash
sudo chmod 600 /etc/sssd/sssd.conf
sudo systemctl restart sssd
sudo systemctl enable sssd
```

#### 2.5 Ensure NSS is using SSSD

Check `/etc/nsswitch.conf`:

```bash
grep '^passwd' /etc/nsswitch.conf
grep '^group'  /etc/nsswitch.conf
```

Ensure `sss` is present, e.g.:

- `passwd: files systemd sss`
- `group:  files systemd sss`

Restart SSSD if you edited it:

```bash
sudo systemctl restart sssd
```

#### 2.6 Validate Kerberos + identity resolution

Kerberos:

```bash
kinit millsks@CLUSTER.HOME.ARPA
klist
```

Identity lookup:

```bash
getent passwd millsks
id millsks
```

If `kinit` succeeds but `id` fails, check SSSD logs:

```bash
sudo tail -100 /var/log/sssd/sssd_cluster.home.arpa.log
```

Common issue:
- `filtered out! (uid out of range)` → increase `max_id` as shown above, then:

```bash
sudo sss_cache -E
sudo systemctl restart sssd
```

---

### Part 3 — (Optional) Centralized home directories via NFS

If you want `/mnt/homes/%u` as home directories across all nodes:

#### 3.1 Mount the NFS export

Create mountpoint:

```bash
sudo mkdir -p /mnt/homes
```

Manual mount test (NFSv4.1):

```bash
sudo mount -v -t nfs4 -o vers=4.1 ymir.cluster.home.arpa:/volume3/homes /mnt/homes
```

Persist in `/etc/fstab`:

```fstab
ymir.cluster.home.arpa:/volume3/homes  /mnt/homes  nfs4  vers=4.1,_netdev,nofail,rw,hard,intr  0  0
```

Apply:

```bash
sudo umount /mnt/homes || true
sudo mount -a
df -h /mnt/homes
```

#### 3.2 Update SSSD to place homes on NFS

Edit `/etc/sssd/sssd.conf`:

```ini
fallback_homedir = /mnt/homes/%u
```

Restart:

```bash
sudo systemctl restart sssd
```

#### 3.3 Ensure the user’s home directory is writable

When using NFSv4.x, permissions are enforced based on **numeric UID/GID**.

On a node, record the AD UID/GID:

```bash
id millsks
```

If the user can log in but gets `Permission denied` in `$HOME`, you likely need to set ownership on the NAS (SSH to the Synology):

```bash
sudo mkdir -p /volume3/homes/millsks
sudo chown <AD_UID>:<AD_GID> /volume3/homes/millsks
sudo chmod 700 /volume3/homes/millsks
```

---

### Part 4 — Troubleshooting quick hits

#### 4.1 `kinit: Client not found in Kerberos database`
- The user likely was created as a **DSM local user**, not an **AD user**.
- Fix: create the user under **Directory Server → Users**.

#### 4.2 `uid out of range` in SSSD logs
- Increase `max_id` (example used: `2000000000`).

#### 4.3 AD works on one interface but not another (wired vs Wi‑Fi)
- Ensure the cluster interface uses Synology DNS.
- Avoid public DNS servers for AD discovery on that interface.

---

### Part 5 — Linux node migration note (local user “shadowing” AD user)

If a local user exists with the same username as an AD user (e.g., local `millsks` and AD `millsks`), the local entry can cause confusion and inconsistent ownership.

Recommended migration approach:

1. Confirm AD user exists and works (`kinit`, `id`).
2. Backup local home directory (rename `/home/millsks` to something safe).
3. Delete local user **without removing the backup directory**.
4. Log in as AD user.
5. If needed, copy files from backup into the AD/NFS home and fix ownership.

---

### Appendix — Minimum test checklist (per node)

```bash
realm list
host -t SRV _kerberos._udp.cluster.home.arpa
kinit <user>@CLUSTER.HOME.ARPA
getent passwd <user>
id <user>
```

If using NFS homes:

```bash
df -h /mnt/homes
mount | grep /mnt/homes
```
