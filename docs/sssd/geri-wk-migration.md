### Synology AD + Linux Node Authentication + NFS Home Directories (cluster.home.arpa)

This document is a step-by-step runbook for this node:

- **Hostname**: geri-wk
- **Role**: Kubernetes control-plane/worker node

It covers:

1. Joining this node to the Synology Active Directory domain
2. Mounting the Synology NFS share for centralized home directories
3. Migrating the existing local user `millsks` to the AD user `millsks` with an NFS-backed home

---

#### Variables (do not change unless your environment changes)

- AD DNS name (domain): `cluster.home.arpa`
- Kerberos realm (uppercase): `CLUSTER.HOME.ARPA`
- Synology (AD DC + DNS) hostname: `ymir.cluster.home.arpa`
- Synology (AD DC + DNS) IP: `172.16.1.221`
- Synology NFS export path: `/volume3/homes`
- Linux mountpoint: `/mnt/homes`
- Migrating user: `millsks`

---

### 1. Install required packages

```bash
sudo apt update
sudo apt install -y realmd sssd sssd-tools adcli samba-common-bin   libnss-sss libpam-sss nfs-common krb5-user
```

---

### 2. Ensure DNS uses the Synology AD DNS

Check DNS status:

```bash
resolvectl status
```

Confirm the primary interface for cluster traffic is using:

- DNS server: `172.16.1.221`
- Search domain includes: `cluster.home.arpa`

Validate Kerberos SRV record:

```bash
host -t SRV _kerberos._udp.cluster.home.arpa
```

---

### 3. Join this node to the AD domain

Discover and join:

```bash
sudo realm discover cluster.home.arpa
sudo realm join cluster.home.arpa -U Administrator
```

Verify:

```bash
realm list
```

You should see a block for `cluster.home.arpa` with `configured: kerberos-member`.

---

### 4. Configure NFS mount for centralized homes

Create mountpoint:

```bash
sudo mkdir -p /mnt/homes
```

Test mount (manual):

```bash
sudo mount -v -t nfs4 -o vers=4.1 ymir.cluster.home.arpa:/volume3/homes /mnt/homes
df -h /mnt/homes
```

Persist in `/etc/fstab` by adding this line:

```fstab
ymir.cluster.home.arpa:/volume3/homes  /mnt/homes  nfs4  vers=4.1,_netdev,nofail,rw,hard,intr  0  0
```

Activate:

```bash
sudo umount /mnt/homes || true
sudo mount -a
df -h /mnt/homes
```

---

### 5. Configure SSSD on this node

Create or overwrite `/etc/sssd/sssd.conf` with:

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
access_provider = simple

use_fully_qualified_names = False
fallback_homedir = /mnt/homes/%u
default_shell = /bin/bash

enumerate = False

ldap_id_mapping = True
min_id = 1000
max_id = 2000000000
```

Apply permissions and restart SSSD:

```bash
sudo chmod 600 /etc/sssd/sssd.conf
sudo systemctl restart sssd
```

Ensure NSS uses SSSD by checking `/etc/nsswitch.conf` has:

```text
passwd:     files systemd sss
group:      files systemd sss
```

If you edit it, restart SSSD again:

```bash
sudo systemctl restart sssd
```

---

### 6. Validate Kerberos and AD identity

Get a Kerberos ticket for `millsks`:

```bash
kinit millsks@CLUSTER.HOME.ARPA
klist
```

Then verify the AD user is visible:

```bash
getent passwd millsks
id millsks
```

You should see a line where the home directory is `/mnt/homes/millsks` and a large UID (e.g. `1746...`).

---

### 7. Backup and remove the local `millsks` user on this node

> Only perform these steps if a local (non-AD) `millsks` exists in `/etc/passwd` and `/home/millsks`.

#### 7.1 Stop any processes for local `millsks`

```bash
sudo pkill -u millsks || true
```

#### 7.2 Backup the existing local home directory

If `/home/millsks` exists:

```bash
sudo mv /home/millsks /home/millsks.local-backup.$(date +%F)
```

#### 7.3 Delete the local user (but keep files)

On Ubuntu/Debian:

```bash
sudo deluser millsks
```

On RHEL-like systems:

```bash
sudo userdel millsks
```

Do **not** use `--remove-home` or `-r`.

Confirm the local user is gone:

```bash
getent passwd millsks
```

If you see only the AD entry (with large UID and `/mnt/homes/millsks`), you are good.

---

### 8. (Optional) Sync local backup data to the NFS home

Only needed on nodes where `/home/millsks.local-backup.*` contains unique data that is not already on the NAS.

```bash
sudo rsync -avh /home/millsks.local-backup.*/ /mnt/homes/millsks/

# Replace with actual UID:GID from `id millsks` on this node
sudo chown -R 1746201105:1746200513 /mnt/homes/millsks
```

---

### 9. Add the AD user to local Linux groups on this node

To mirror the old local memberships:

```bash
sudo usermod -a -G adm,cdrom,sudo,dip,plugdev,lxd,docker millsks
```

Verify:

```bash
id millsks
```

You should see `adm`, `sudo`, `docker`, etc. in the groups list.

---

### 10. Final validation on this node (geri-wk)

Log in as the AD user:

```bash
su - millsks
```

Then check:

```bash
whoami
pwd
echo "$HOME"
df -h .

# Test write access to home
ls -la
mkdir -p ~/test-from-geri-wk
touch ~/test-from-geri-wk/file.txt
```

Expected:

- `whoami` → `millsks`
- `pwd` and `$HOME` → `/mnt/homes/millsks`
- `df -h .` → shows `ymir.cluster.home.arpa:/volume3/homes`
- No `Permission denied` when listing or writing in `$HOME`.

If all checks pass, this node is fully migrated to use the AD `millsks` with an NFS-backed home directory.
