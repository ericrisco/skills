# Install & proxy — deep dive

Source facts: coolify.io/docs/get-started/installation and proxy docs, accessed 2026-06-02. Coolify 4.x.

## Full install transcript (Ubuntu 22.04/24.04 LTS)

```bash
# Provision the box first (hetzner / digitalocean). Floor: 2 CPU / 2 GB / 30 GB.
# Comfortable multi-app production: 4 vCPU / 8 GB / 100 GB NVMe. Coolify idles ~1 GB RAM.

ssh root@<server-ip>            # root required; non-root is not fully supported

# Optional sanity: confirm OS + free disk before install
cat /etc/os-release
df -h /

# Install (downloads + runs the official script; installs Docker + Coolify's own stack)
curl -fsSL https://cdn.coollabs.io/coolify/install.sh | bash
# Some docs show `| sudo bash` when piping; on a root shell `| bash` is correct.
```

The script takes ~2–5 minutes. When it finishes it prints the dashboard URL: `http://<server-ip>:8000`.

### Claim the admin account (do this immediately)

Open `http://<server-ip>:8000` and register. The **first** account created becomes the permanent root
admin of the instance — there is no later ownership-claim or admin-invite recovery flow. Until you
register, anyone who can reach `:8000` can take the instance. Do not pause between the install finishing
and this step.

After registering, in the dashboard:

1. Settings → Instance: set the **FQDN** (e.g. `coolify.example.com`) and enable **force HTTPS** so the
   dashboard itself gets a Let's Encrypt cert and you stop using the raw `:8000` IP.
2. Point the dashboard FQDN's DNS A record at the box (DNS records are the `domains-dns` skill).

## Other OS / non-LTS notes

- **Ubuntu non-LTS** (e.g. interim releases): supported but the installer may need manual Docker repo
  steps — install Docker Engine first, then re-run the Coolify script.
- **Debian / Fedora / AlmaLinux / Rocky / CentOS / SUSE / Arch / Alpine**: supported. On distros where the
  script can't add the Docker repo automatically, install Docker Engine via the distro's official method,
  then run the Coolify script.
- **Raspberry Pi OS**: 64-bit only.
- General rule: if the one-liner fails partway, the usual cause is Docker not installing cleanly. Install
  Docker by hand, verify `docker run --rm hello-world`, then re-run the Coolify script (it is idempotent).

## Proxy: Traefik (default) vs Caddy

Coolify ships **Traefik** as the default reverse proxy and can use **Caddy** instead. The proxy owns ports
80/443, routes hostnames to containers, and provisions Let's Encrypt certificates automatically.

- **Traefik (default)**: keep it unless you have a specific reason. Most templates and docs assume it.
- **Caddy**: switch in Settings → Proxy if you prefer Caddy's config model. Don't switch mid-flight on a
  busy instance without a maintenance window — the proxy restarts.

You rarely hand-edit proxy config; Coolify generates labels/routes from each resource's domain settings.
For a per-resource custom rule, use the resource's "Custom Traefik/Caddy labels" field rather than editing
the proxy container directly (your edit would be overwritten on regeneration).

## Wildcard domain + DNS-01 challenge

For `*.apps.example.com` (one cert for many subdomains) Let's Encrypt requires the **DNS-01** challenge,
which needs API access to your DNS provider so the proxy can create the `_acme-challenge` TXT record.

1. Create a scoped DNS API token at your provider (Cloudflare, etc.).
2. Configure the DNS provider + token in the proxy/ACME settings.
3. Request the wildcard cert. The HTTP-01 challenge (the default for single hosts) cannot issue wildcards.

Single-host certs use HTTP-01 and need only port 80 reachable + the A record pointing at the box.

## Common SSL failures and fixes

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| Cert never issues, "connection refused" in ACME logs | Port 80 not reachable from the internet | Open 80 at the cloud firewall; HTTP-01 needs it even for HTTPS-only sites |
| "DNS problem: NXDOMAIN" | A record missing or not propagated | Confirm the A record points at the box; wait for propagation (domains-dns) |
| Wildcard cert fails on HTTP-01 | Wildcards require DNS-01 | Configure the DNS provider token and use DNS-01 |
| Rate-limit / "too many certificates" | Hit Let's Encrypt issuance limit by retrying | Wait out the limit; use staging while debugging, then switch to production |
| Dashboard at `:8000` has no cert | FQDN + force HTTPS not set | Set the instance FQDN and enable force HTTPS in Settings |
