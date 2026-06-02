# Droplet ops — cloud-init, cloud firewall, snapshots, reserved IP, VPC

A Droplet is a Linux VPS you own end to end. The discipline below keeps it secure and
recoverable. Per-second billing has applied since 2026-01-01 (min 60s or $0.01) — short-lived
Droplets are cheap, but storage bills even when powered off, so **destroy** rather than power
off to stop charges.

## Bootstrap with cloud-init (user-data)

Pass a cloud-init file so the box is configured on first boot — no manual SSH-and-poke.

```yaml
# cloud-init.yaml
#cloud-config
package_update: true
packages:
  - ufw
  - fail2ban
users:
  - name: deploy
    groups: sudo
    shell: /bin/bash
    ssh_authorized_keys:
      - ssh-ed25519 AAAA... you@host
runcmd:
  - ufw allow OpenSSH
  - ufw --force enable
  - systemctl enable --now fail2ban
```

```bash
doctl compute droplet create web-1 \
  --region nyc3 --size s-1vcpu-1gb --image ubuntu-24-04-x64 \
  --ssh-keys <fingerprint> --vpc-uuid <vpc-uuid> \
  --user-data-file cloud-init.yaml --wait
```

## Cloud firewall (the real perimeter)

A DO cloud firewall filters at the edge before traffic hits the box and applies to a tag, so
new Droplets with that tag inherit it automatically. Treat host `ufw` as defense-in-depth.

```bash
doctl compute firewall create \
  --name web-fw \
  --tag-names web \
  --inbound-rules "protocol:tcp,ports:22,address:<your.office.ip>/32 protocol:tcp,ports:80,address:0.0.0.0/0,address:::/0 protocol:tcp,ports:443,address:0.0.0.0/0,address:::/0" \
  --outbound-rules "protocol:tcp,ports:all,address:0.0.0.0/0,address:::/0 protocol:udp,ports:all,address:0.0.0.0/0,address:::/0"
```

Principles:

- Restrict SSH (22) to known IPs, not `0.0.0.0/0`.
- Open only the ports the service needs (80/443 for web).
- Keep DB ports closed at the edge entirely — the DB should be reached over the VPC, never
  the public internet.

## Snapshots & backups

- Enable **automated backups** for set-and-forget restore points.
- Take a **manual snapshot before any risky change** (kernel upgrade, migration host).
- Restore by creating a new Droplet from the snapshot/backup image, then re-point the
  reserved IP at it.

```bash
doctl compute droplet-action snapshot <droplet-id> --snapshot-name pre-upgrade --wait
doctl compute snapshot list
```

## Reserved IP failover

A reserved IP is **free while assigned** to a Droplet, billed when unassigned. Keep your
public DNS pointed at the reserved IP, never at a Droplet's ephemeral IP. To fail over:

```bash
doctl compute reserved-ip-action assign <reserved-ip> <new-droplet-id>
```

Traffic moves to the replacement Droplet without touching DNS. Release reserved IPs you no
longer use so they stop billing.

## VPC + private DB layout

Put app Droplets and the Managed Database in the **same VPC and region**. Then:

- App → DB traffic rides the VPC private host: no bandwidth charge, sub-ms latency, off the
  public internet.
- Add the app Droplet (or its tag) as a **trusted source** on the DB so nothing else can
  connect, even with the credentials.
- The public web edge only ever sees ports 80/443 on the app Droplets; the DB has no public
  ingress at all.

In prose, the topology is: `internet → cloud firewall (80/443) → app Droplets (VPC) →
private DB host (trusted source) → Managed Postgres`. Spaces sits outside the VPC and is
reached over its S3 endpoint with Spaces keys.
