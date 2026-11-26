# Homelab security monitoring & hardening plan (2026-11)

Status: **in progress** — Phase 1.1–1.6 deployed and verified 2026-11-26; the
jails' first real ban was the home WAN, now in `ignoreip` (see §0.2 and the
logbook). Next: Phase 2 (edge hardening), then 3+.
Author: agent (gap analysis of repo state at `delvison/homelab`)
Date: 2026-11-25
Scope: public edge (`vps` Caddy), the edge→home bridge, host integrity, backup
strategy, supply chain. Covers *detection* and *hardening*; not app feature work.

## 0. Related / prior plans (do not duplicate)

- `~/.opencode/plan/suricata-ntfy.md` — **network** IDS (Suricata + ntfy) on the
  gateway/router. Orthogonal: this plan covers the **edge** (VPS/Caddy), **host**
  integrity, **authz**, and **segmentation**. Suricata stays the network layer;
  Phase 5's CrowdSec is the host/log layer. Reuse that plan's ntfy conventions.
- `~/.opencode/plan/cve-2026-123158-openssh-alpine.md` — Alpine `sshd` (`sshole`).
  Reinforces Phase 2.2; check whether any host here is Alpine+musl.
- `.opencode/plans/gl-inet-kvm-cloud-incident-2026-11.md` — prior GoodCloud/KVM
  incident; motivates monitoring/segmenting IoT/BMC devices (Phase 5).
- `~/.opencode/plan/docker-host.md` — rootless docker module; relevant to Phase 6.

## 0.1 Progress

| Date | Phase | What shipped | State |
|---|---|---|---|
| 2026-11-25 | 1.4 | `roles/otelcol` on the VPS ships Caddy access logs + host metrics over OTLP | **done** — `eb96134` |
| 2026-11-25 | 1.4a | LAN agent bounded, temporality fixed, metric renamed to end the collision | **done** — `66c54a5` |
| 2026-11-25 | — | Caddy 2.11.9 + single validated restart handler (prereq for 2.1/2.4) | **done** — `2673845` |
| 2026-11-25 | — | `prometheus-init` fail-safe (needed so agent restarts don't kill the scrape path) | **done** — `e74104d` |
| 2026-11-25 | 1.2 | Filters repaired (they never compiled), 4 Caddy jails collapsed to 2, ntfy ban action + shared `[DEFAULT]`, `fail2ban-regex` compile gate | **done** — `b0a2fa7` |
| 2026-11-25 | 1.1 | ntfy `security` user + write-only ACL + `fail2ban` token | **done** — token in the vault, value not recorded |
| 2026-11-25 | 1.2 deploy | `just run-caddy` on the VPS | **done** — both jails loaded, `action = %(action_)s` + `ntfy`, verified from two hosts |
| 2026-11-25 | 1.2 verify | Publish path proved with the real token (200), bogus token (401), read-back with the write-only token (403); ban → notification confirmed by the user | **done** — see §0.3 |
| 2026-11-25 | 1.2 incident | The new jails banned the home WAN from 80/443 (NAT, one address). Unbanned and added it to `caddy_fail2ban_ignoreip` | **resolved** — see `Logbook/2026-11-25` 23:22 |
| 2026-11-25 | — | `del` granted read-only on `security` (manual, not in Ansible) | **done, out-of-band** — see §0.3 |
| 2026-11-25 | 1.3 deploy | logwatch timer on the home hosts | **deployed 2026-11-26** — delivery proven by 200s from all three hosts |
| 2026-11-26 | 1.5 | `services/monitoring/prometheus/alerts/security.yml`: block burst (status 0), 5xx rate, `CaddyNoTraffic`; 429 dropped (no limiter) | **deployed** — `promtool` 3 rules on the host; 4000 `host_name="vps"` series confirm the data |
| 2026-11-26 | 1.6 | `heartbeat` container: pings healthchecks only while the VPS edge answers | **deployed** — check and token in place, ping confirmed; the alarm leg is accepted untested |
| 2026-11-26 | — | proxmox's `9100` was blocked by **ufw** (not pve-firewall, which is disabled); the rule now lives in `roles/node_exporter` | **applied and verified** — ufw rule present, `NodeExporterDown` resolved |
| 2026-11-26 | — | `CaddyHighUpstreamLatency` deleted: Caddy's `handler` label is `subroute` on every nested route, so the alert named nothing | **deployed** — 4 rules loaded, alert resolved |
| 2026-11-26 | — | alertmanager `9093` was published on the LAN with no auth (read alerts, create silences) | **deployed** — bound to `127.0.0.1`, `d8e1959` |
| 2026-11-26 | 1.7 | `security.json` provisioned from git: edge rate, blocks, 5xx, by status/host, URI classes, firing alerts. Top-IP panel dropped: the connector strips IPs | **done** — `8ff47b4`, verified live |
| — | 2–9 | see below | not started |

**Deviations from the plan as written.** Read these before implementing 1.5 and
1.7, because they change what is possible with the metrics:

1. The derived metric is `caddy.access.requests` → `caddy_access_requests_total`,
   **not** `caddy.http.requests` as §1.4 originally said. Caddy's own `/metrics`
   already publishes `caddy_http_requests_total`; two sources under one name
   double-counted every `rate()`.
2. **No `remote_ip`/`client_ip`/`ts`/`duration` labels** (§1.4 asked for
   client/remote IP). Per-client series put client addresses into long-term
   storage and create one series per address; the receiving collector's
   prometheus exporter never expires a series. Consequence: §1.7's "top offending
   IPs" cannot come from these metrics — take it from fail2ban instead
   (`fail2ban-client`, jail log, or a textfile exporter).
3. The `count` connector emits **delta** temporality, so both agents run
   `deltatocumulative` before export. Without it Prometheus reads per-scrape
   increments and invents counter resets.
4. `uri_class` is the first path segment, and only when it matches
   `^[A-Za-z0-9._-]{1,16}$`; everything else folds into `uri_class="other"` so
   scanner paths cannot mint series.
5. The labels that exist on the derived metric are exactly `environment,
   host_name, method, server_name, status, uri_class`. In particular it is
   **`status`**, not `code`, so alert expressions must not copy Caddy's native
   label names.
6. Restarting `otel-collector` zeroes every OTLP-derived counter (the exporter is
   in-memory). A reset there is expected, not an incident.
7. `*.local.<domain>` resolves to `192.168.1.178` (the LAN Caddy), not the VPS,
   so §7.4 is answered: the monitoring UIs are not internet-reachable.

## 0.2 Deploy runbook for Phase 1.1–1.2 (**executed 2026-11-25**)

Kept as the re-run recipe. Every Ansible recipe that reaches the VPS asks for
the sudo password (`become_ask_pass = True`), which the vault's `admin_password`
is **not**; type it at the `-K` prompt.

On the VPS, as root:

```sh
# User and topic are both named "security" (different namespaces).
ntfy user add --role=user --ignore-exists security
ntfy access security security write-only      # publish only, no read-back
ntfy token add --label=fail2ban security      # prints tk_... once; copy it
ntfy access security                          # confirm: security security write-only
```

Then, in `infrastructure/ansible/vars/vault.yml` (mode 600, never committed):

```yaml
ntfy_security_token: "tk_..."     # write-only, security topic
ntfy_security_topic: "security"   # optional; defaults to security
caddy_fail2ban_ignoreip: "<home WAN address>"   # required, see below
```

Re-encrypt to `vars/vault.yml.enc`, then:

```sh
just run-caddy        # prompts for the sudo password
```

Verify:

```sh
ssh vps 'sudo fail2ban-client status'                 # caddy + caddy-envscan
ssh vps 'sudo fail2ban-client status caddy'
ssh vps 'sudo fail2ban-client get caddy ignoreip'
ssh vps 'sudo ls -l /etc/fail2ban/action.d/ntfy.conf' # 0640 root:root
```

Then confirm one real notification without touching the firewall: ban a
TEST-NET-3 address and unban it.

```sh
ssh vps 'sudo fail2ban-client set caddy banip 203.0.113.99'
ssh vps 'sudo fail2ban-client set caddy unbanip 203.0.113.99'
```

**The ignoreip entry is not optional here.** On first deploy the jails banned
the home WAN within minutes: the whole house shares one NAT address, and 5x 4xx
in 60s on `port = http,https` is one page load's worth of stale assets. The
symptom is a REJECT, so `curl` says *connection refused* while Caddy is
verifiably up, SSH on 2245 still works, and other sites' 443 works. Cost of
ignoring the WAN: a compromised LAN device can probe the edge unpunished. The
alternative is raising `maxretry` on `[caddy]` and keeping the ban.

Rollback: delete `ntfy_security_token` from the vault and re-run `just run-caddy`.
The jail template then renders without an `action` key and the ntfy action file
is removed, so bans go back to the stock action.

For Phase 1.3 (home hosts only), **do not run `just run-all`**: `site.yaml` is
`hosts: all`, which includes `vps`, so it would push the base role's ufw and
fail2ban changes to the edge as well. Limit it:

```sh
ansible-playbook -i inventory.ini site.yaml --limit server,proxmox,debian-vm -K
systemctl list-timers logwatch-ntfy.timer
sudo systemctl start logwatch-ntfy.service   # send one now
journalctl -u logwatch-ntfy.service -n 20
```

As of 2026-11-25 that last step is still pending: `/etc/systemd/system/logwatch-ntfy.*`
does not exist on `server`, and the timer is inactive on `proxmox`.

## 0.3 ntfy identity model, verification, and what is not in the repo

**Who can do what** (`auth-default-access: deny-all`, so everything not listed is
denied):

| Principal | Role | ACL | Used by |
|---|---|---|---|
| `security` | `user` | `security` → write-only | fail2ban `action.d/ntfy.conf`, logwatch timer |
| `del` | `user` | `security` → read-only (granted manually) | human subscription (web/phone) |
| `*` (anonymous) | — | none | nothing: every publish needs the token |

The token (`tk_…`, 32 chars) belongs to `security`; tokens inherit the user's ACL
and cannot be scoped further, so write-only on the topic is what limits the
damage if the token leaks.

**Verification, 2026-11-25** — publish path exercised with the real vault token
and the exact headers/body `actionban` sends:

- publish → `200`, message accepted on `security` with the expected title and body
- same publish with a bogus token → `401 unauthorized` (auth is enforced, the 200
  was not an open topic)
- read the topic back with the write-only token → `403` (ACL honoured)
- a real ban from `fail2ban-client set caddy banip …` → notification received
  (user-confirmed)

**Not in the repo, and this is the gap:** users, ACLs and tokens live only in
`/var/lib/ntfy/user.db` on the VPS. `roles/ntfy-server` creates none of them,
so a rebuild silently removes every credential and both readers of
`security`. ntfy
supports declaring all three in `server.yml` (`auth-users`, `auth-access`,
`auth-tokens`), but declarative users are *deleted* when removed from the config,
so adopting it needs a deliberate migration and a password hash for each user.

**Vault caveat found while committing:** `sops -d vars/vault.yml.enc` fails with
`Could not unmarshal input data`, because `.enc` is not a format sops recognises.
`--input-type yaml` parses it and reaches the normal key lookup. Decryption was
not performed: this machine holds the age identity only as a passphrase-encrypted
`~/.config/sops/age/keys.txt.age`. The re-encrypted file is structurally valid
and targets the recipient in `.sops.yaml`, but "does the backup actually decrypt"
is still open question 5.

## 1. Context

Public entry is the `vps` host running Caddy (`infrastructure/ansible/roles/caddy`,
`caddy_server.yaml`). Cloudflare DNS is `proxied = false`
(`infrastructure/terraform/cloudflare/main.tf`), so traffic hits the VPS directly.
The VPS proxies into RFC1918 LAN addresses over the overlay
(`vault.yml`: `server1=192.168.1.224`, `server3.server.local`, …), which makes
Caddy on the VPS a **bridge from the internet into the homelab network**.

Prevention is decent (fail2ban, Caddy security headers, bot/attack-path blocking,
admin API bound to localhost). The gaps are **detection/alerting**,
**network segmentation**, **host integrity**, and a few concrete config flaws.

Threat model for prioritisation: an internet-exposed VPS is scanned
continuously; the realistic incidents are credential stuffing on exposed login
forms, a CVE in an exposed app, supply chain via auto-pulled `latest` images,
and lateral movement from
a popped edge into the home network.

## 2. Goals / non-goals

### Goals

- Alert on security-relevant events within minutes (ntfy), not "sometime".
- Make the edge→home trust boundary deny-by-default.
- Detect host-level compromise (new processes/binaries/units), not just web noise.
- Remove single points of failure in the domain (Cloudflare token) and backups.

### Non-goals

- Rewriting the reverse-proxy layout or migrating services.
- Full SIEM / Wazuh (kept as an optional Tier 2).
- Deep packet inspection — owned by `suricata-ntfy.md`.

## 3. Phase 0 — Verify read-only before changing anything

- [ ] `sudo ufw status verbose` on `vps` — active? is 80/443 allowed? (`base` only
      allows OpenSSH; `caddy` adds nothing.)
- [ ] On `vps`: `sudo sshd -T | grep -Ei
  'passwordauth|permitrootlogin|allowusers|port'`.
- [ ] Is `*.local.<domain>` publicly resolvable to the VPS, or split-horizon? Affects
      whether `otel.`/`grafana.`/`prom.` are internet-reachable.
- [ ] How does the VPS reach `192.168.1.0/24` — Tailscale advertise-routes, Nebula
      `unsafe_routes`, or wg? Determines edge-compromise blast radius.
- [ ] Tailnet policy: default is allow-all unless `acls` exist.
- [x] `sudo fail2ban-client status`; `fail2ban-regex` a real
      `/var/log/caddy/*.access.log` against `/etc/fail2ban/filter.d/caddy.conf`.
      **2026-11-25: the filter did not compile at all** (`re.error: redefinition
      of group name 'd'`), so every Caddy jail was dead. Fields were also matched
      in the wrong order and `ignoreregex` used a field that does not exist. Fixed
      in `b0a2fa7`; the play now gates on `fail2ban-regex`.
- [ ] Which images are unpinned: `docker compose config --images` per service.
- [ ] Cloudflare token scope — should be `Zone:DNS:Edit` + `Zone:Zone:Read` only.

Record results in §4 before Phase 1.

## 4. Findings (severity)

| # | Sev | Finding | Location |
|---|---|---|---|
| A | ~~High~~ **fixed, verified** | fail2ban bans were silent; `logwatch` mailed `root` with no MTA. Ban → ntfy is deployed and **confirmed end to end** (publish 200, bogus token 401, write-only read 403, and a real ban notification received). logwatch→ntfy is committed (`dd53d34`) but not yet deployed to the home hosts | `roles/caddy`, `roles/base` |
| B | ~~High~~ **fixed** | VPS Caddy access logs ship nowhere → **resolved 2026-11-25** by `roles/otelcol` (Phase 1.4) | `roles/otelcol` |
| C | High | Flat tailnet; edge compromise reaches all home services (and LAN if routed) | no ACLs in repo |
| D | High | No host integrity / audit (`auditd`, `aide`, `rkhunter`) anywhere | repo-wide |
| E | ~~Med~~ **fixed** | Caddy fail2ban filters **did not compile** (`%d{2}` in a strptime datepattern → duplicate group `d`), so both jails were dead while `fail2ban-server --test` still said OK; the regexes also required `status` before `remote_ip` and ignored `request_uri`. Repaired, jails collapsed, compile gate added — **2026-11-25**, `b0a2fa7` | `roles/caddy/templates/caddy-filter.conf.j2` |
| F | Med | ufw 80/443 not codified; drift possible | `roles/base`, `roles/caddy` |
| G | Med | authentik exists but no `forward_auth` — every public app exposes its own login | `services/authentik` vs `Caddyfile.j2` |
| H | Med | Cloudflare not proxying → no WAF/DDoS/bot layer; origin IP public | `terraform/cloudflare/main.tf` |
| I | Med | Watchtower rw docker.sock + unpinned `latest`, auto-deploy, no update notify | `services/watchtower`, `monitoring/docker-compose.yml` |
| J | Med | Secrets: untracked plaintext `vault.yml`; ntfy token inlined in `alertmanager-ntfy/config.yml` (untracked → leaks if committed) | `vars/vault.yml`, `monitoring/` |
| K | Low | `abort` matchers return empty replies for broad paths (`/admin/*`, `/data/*`, `/status`, `/files/*`) → likely false positives | `Caddyfile.j2` |
| L | Low | No L7 rate limit on login endpoints | `Caddyfile.j2` |
| M | Low | Home Caddy admin API on `0.0.0.0:2019` | `services/caddy/local/docker-compose.yml` |
| N | Low | OTLP endpoint is a static-token data sink; Grafana anonymous-viewer exposes topology | `monitoring/otelcol`, `grafana` |
| O | Low | Offsite backup is plain rsync — no immutability/append-only | `services/backup-offsite` |
| P | Med | **No fail2ban exporter exists**, so the `fail2ban_banned_current` alert sketched in Phase 1.5 has no data source. Bans are currently invisible to Prometheus *and* to ntfy — the two gaps compound | `services/monitoring` |
| Q | ~~Med~~ **mostly fixed** | Caddy jails come from `roles/caddy` (`jail.d/caddy.conf`) and `roles/base` writes `sshd.conf`/`tailnet.conf`. `roles/caddy` now deploys `jail.d/00-ansible-defaults.conf` with a host-wide `[DEFAULT]`, so every jail on a Caddy host inherits `ignoreip` and `bantime.increment`. A host that runs only `roles/base` still gets neither | `roles/caddy`, `roles/base` |
| R | Low | Caddy's native metrics are the only `caddy_*` source Prometheus still reads for handler-level data, and the wildcard vhost hides the hostname — every upstream series is keyed by `handler`, not site | `Caddyfile.j2` |
| S | ~~Med~~ **fixed** | Proxmox's node exporter was unreachable, so `NodeExporterDown` fired for real: ufw (active; only 22 allowed) blocked `9100` from `192.168.1.180`, confirmed in `/var/log/ufw.log`. pve-firewall is disabled and was never the cause. `roles/node_exporter` now allows the monitoring host and the play points at it | `roles/node_exporter`, `proxmox.yml` |

## 5. Phased plan

### Phase 1 — Alerting plumbing (P0)

1. **Dedicated ntfy security topic/token** — topic `security`, add
   `ntfy_security_token` + `ntfy_security_topic` to `vars/vault.yml.enc`.
   **Blocked**: `ntfy` is `auth-default-access: deny-all`, the `ntfy-server` role
   creates no users or tokens, and only root on the VPS can mint one. The token
   must be created by hand and pasted into the vault (see §0.2 runbook).
2. **[code done 2026-11-25, deploy pending token] fail2ban → ntfy.** Implemented
   in `roles/caddy`, not `roles/base`: the Caddy jails live there, and the VPS
   does not run `roles/base` at all (`caddy_server.yaml` is `caddy` + `otelcol`).
   - `templates/fail2ban-ntfy.conf.j2` → `/etc/fail2ban/action.d/ntfy.conf`
     (0640): one `curl` `actionban` with a bearer token, empty start/stop/check/
     unban hooks so a failed notification can never block a ban.
   - `templates/fail2ban-defaults.conf.j2` → `jail.d/00-ansible-defaults.conf`:
     `[DEFAULT] ignoreip` = loopback + RFC1918 + CGNAT + Nebula, plus
     `bantime.increment/factor 2/maxtime 48h`. Extra addresses come from
     `caddy_fail2ban_ignoreip` (default `""`), never the repo.
   - Attached as `action = %(action_)s` **plus** `ntfy`, so the distro firewall
     ban still runs. Gated on `ntfy_security_token`, so a host without a token
     renders no `action` key and keeps the stock behaviour.
   - **`ignoreip` must include the monitors** (`gatus`/`uptime-kuma` egress) else
     self-probes get banned. `gatus` currently probes the public edge with
     `User-Agent: Gatus/1.0`, arriving from the home WAN address.
   - Resolves the Caddy half of finding Q; `roles/base` still deploys no shared
     defaults, so a host without the caddy role keeps none.
3. **[code done 2026-11-25] logwatch digest → ntfy** (`roles/base`,
   `dd53d34`): a `logwatch-ntfy.service` oneshot plus a daily
   `logwatch-ntfy.timer` (06:17, 15m jitter, `Persistent=true`) run
   `logwatch --range yesterday --detail low --output stdout` and post the body to
   the security topic at priority `low`. The token is an `EnvironmentFile` at
   `/etc/logwatch/ntfy.conf` (0600); the digest is truncated to its last 3500
   chars because ntfy rejects larger bodies. `logwatch.conf.j2` still says
   `Output = mail` on purpose — the stock `/etc/cron.daily/00logwatch` reads that
   file, and `--output stdout` overrides it, so nothing else changes. No token
   means no timer and no leftover units.
   Only reaches hosts that run `roles/base` (`site.yaml`), i.e. not the VPS.
   This answers open question 2: ntfy, not an MTA.
4. **[done 2026-11-25]** Ship VPS Caddy logs off-box. Implemented as a new
   `roles/otelcol`, not inside `roles/caddy`: otelcol-contrib 0.109.0 from the
   release `.deb`, config at `/etc/otelcol-contrib/config.yaml` (0640) plus a
   0640 env file holding `OTLP_ENDPOINT`/`OTEL_AUTH_TOKEN`. It tails Caddy's
   access log, converts each record to a counted metric and exports it over OTLP
   HTTP alongside Caddy and host metrics. Metric is
   `caddy.access.requests` → `caddy_access_requests_total`, labelled
   `environment, host_name, method, server_name, status, uri_class` — no client
   IP, `ts` or `duration` (see §0.1 for why, and for what that costs §1.7).
   Off-box matters: root on the VPS can wipe local logs.
   Verified end to end: 8 series for `host_name="vps"`, `status`/`uri_class`
   cardinality bounded, `sum()` rising monotonically across generated requests,
   zero `remote_ip`/`client_ip` series, and `caddy_http_requests_total` back to
   carrying only Caddy's own series.
5. **[code done 2026-11-26] Alertmanager security rules**
   (`services/monitoring/prometheus/alerts/security.yml`):

   ```yaml
   groups:
     - name: security
       rules:
         # Only fires once Phase 1.1–1.2 add a fail2ban metric source (finding P).
         # Until then, bans alert directly from the fail2ban action.
         - alert: Fail2banBanSpike
           expr: increase(fail2ban_banned_current[10m]) > 20
           for: 5m
           labels: {severity: warning}
         - alert: Caddy403Burst
           expr: sum(rate(caddy_access_requests_total{status="403"}[5m])) > 2
           for: 5m
           labels: {severity: warning}
         - alert: Caddy429Burst
           expr: sum(rate(caddy_access_requests_total{status="429"}[5m])) > 1
           for: 5m
           labels: {severity: warning}
         - alert: Caddy5xxRate
           expr: sum(rate(caddy_access_requests_total{status=~"5.."}[5m])) > 0.5
           for: 10m
           labels: {severity: critical}
         - alert: CaddyNoTraffic
           # edge received nothing for 15m: either the internet died or the
           # agent did. Pairs with the dead-man's switch in 1.6.
           expr: sum(increase(caddy_access_requests_total{host_name="vps"}[15m])) == 0
           for: 0m
           labels: {severity: warning}
   ```

   Notes: the derived metric uses `status`, not Caddy's `code`, and carries
   `host_name`, so filter to the edge with `host_name="vps"`. `TlsCertExpiring`
   is dropped from this block until the metric name is confirmed — Caddy's native
   endpoint did not show a cert-expiry series in the current output, so it must
   be checked against `caddy_metrics` (or scraped from the cert files) rather
   than assumed. Route the group to `ntfy`; extend
   `alertmanager.template.yml`.

   **As built (2026-11-26):** 3 rules, validated with `promtool check rules`
   from the prod image (`prom/prometheus:v2.55.0`). Measured against 3 days of
   VPS access logs (2026-11-23 → 11-26), which changed two of the sketch's
   rules:
   - `Caddy403Burst` became **`CaddyBlockBurst` on `status="0"`**. Caddy's
     block rules (`@bad_ua`, `@attack_paths`, `@bad_methods`, the catch-all
     `handle { abort }`) close the connection, which logs as status **0**. 403
     on this edge is an *app* denying: 11562 of 11565 403s in the sample were
     ntfy answering a subscriber with no read access on `alerts`. Observed
     status-0 baseline ~60/hour, peak 47 per 5 min, so `> 1/s` for 5m needs a
     6x spike.
   - **No 429 rule.** Zero 429s in the sample and no `rate_limit` in the
     Caddyfile, so nothing can produce one; Cloudflare is not proxying yet
     (finding H). Add it with the limiter, not before.
   - `Fail2banBanSpike` is **not** included. `fail2ban_banned_current` does not
     exist, and a rule over a missing metric can never fire — dead config that
     looks like coverage. Bans page through the fail2ban ntfy action instead
     (Phase 1.2). Add the rule when finding P ships an exporter.
   - No `alertmanager.template.yml` change is needed: `receiver: ntfy` is
     already the default route and `alertmanager-ntfy` publishes to topic
     `alerts`. So these rules land in **`alerts`**, while fail2ban bans land in
     **`security`**. That split is fine (different blast radius, different
     priority) but it means one incident can show up in two places.
   - 401 is deliberately absent: the public site is behind basic auth, so
     credential stuffing is a 401 burst, and so is every unauthenticated
     visitor. Worth adding only with a per-host threshold.
   - **Deploy bug fixed with the commit:** `prometheus/web.yml` was tracked but
     is rendered on the host by the `prometheus-init` container, which makes it
     root-owned, so the next `push-files` scp could not overwrite it and
     `just deploy` stopped before `docker compose up`. The placeholder is gone
     and the path is in `services/monitoring/.gitignore`; nothing mounts the
     file directly (both containers mount the directory), so init recreates it.

   Deploy: `just deploy` in `services/monitoring` (pushes `prometheus/` and
   force-recreates), or reload only: `curl -X POST -u admin:$PASS
   http://<monitoring>:9090/-/reload`. Verify: `promtool` output above, then
   `/api/v1/rules?type=alert` shows the `security` group; no rule should be in
   `pending`/`firing` on quiet traffic.
6. **[code done 2026-11-26] Dead-man's switch** — inverted from the sketch. The
   sketch had the VPS ping `healthchecks` (house), which needs a VPS→house hole
   through the very boundary Phase 2 closes. Instead a `heartbeat` container on
   the monitoring host (`.180`) pings `healthchecks` (`.224`) **only while the
   VPS `/v1/health` answers**, every 10 minutes:
   - VPS dead or its ntfy dead → no ping → healthchecks marks the check down.
   - monitoring host dead → no ping → same check, from a different host.
   - delivery: healthchecks → **VPS ntfy** (public `alerts` topic, dedicated
     `alerting` user with write-only on `alerts`). This was chosen over a house
     ntfy token to avoid a second credential set and a second subscription on
     the phone. It costs the case it was designed for: if the VPS dies,
     healthchecks records the missing heartbeat but cannot announce it. What it
     still covers is `.180` dying and the heartbeat itself breaking — neither
     has any other alert path. Upgrade path: add a second healthchecks
     integration pointed at the house ntfy (`server:12500`) so the VPS-death
     case is delivered too; the heartbeat needs no change.
   Traffic is house→VPS and house→house, so no new inbound path to the house.
   Needs two `.env` values (`EDGE_URL`, `HC_PING_URL`); compose refuses to start
   the service without them rather than silently sending nothing. `HC_PING_URL`
   must use the LAN-caddy name, and the service pins that name in `extra_hosts`
   (`192.168.1.178`): the monitoring host's resolver answers NXDOMAIN for the
   LAN zone (2026-11-26: `nslookup` returned the CNAME then NXDOMAIN, `wget`
   reported `bad address`), so a bare lookup there never works. Cost: a pinned
   address — moving the LAN proxy needs a one-line edit here.
   Not covered: `.224` dying (it hosts ntfy, gatus and healthchecks, so nothing
   house-side can speak — Prometheus on `.180` still alerts through the VPS),
   and the whole house going dark. Both are visible to a human.
7. **Grafana dashboard** `security.json`: bans over time, top offending IPs,
   403/404/429 by host, unique-URI ratio, unknown-Host hits.

**Verify:** `fail2ban-client set sshd banip 203.0.113.7` → ntfy fires; kill the VPS
otel sender → alert fires; dashboard shows VPS traffic.

### Phase 2 — Edge hardening (P0)

1. **Codify firewall** (`roles/caddy/tasks/main.yml`):

   ```yaml
   - name: allow http/https
     community.general.ufw:
       rule: allow
       port: "{{ item }}"
       proto: tcp
     loop: ["80", "443"]
   ```

   and in `roles/base`:

   ```yaml
   - ufw: {policy: deny, direction: incoming}
   - ufw: {policy: allow, direction: outgoing}
   ```

2. **SSHD hardening** (`roles/base` + `templates/sshd_config.d/99-hardening.conf.j2`):

   ```ini
   PasswordAuthentication no
   PermitRootLogin no
   KbdInteractiveAuthentication no
   MaxAuthTries 3
   X11Forwarding no
   ```

   Confirm key login first. Cross-check `cve-2026-123158-openssh-alpine.md`.
3. **Fix fail2ban Caddy filter** (`templates/caddy-filter.conf.j2`):
   - match the parsed client IP, tolerant of `trusted_proxies`:
     `("client_ip"|"remote_ip"):"<HOST>"`.
   - drop the `"level":"error"` regex from the access-log filter (it's the error
     log) or give it its own jail on `error.log`.
   - make `caddy-invalid` genuinely host-aware (or fold into `caddy-scan`).
   - test: `fail2ban-regex /var/log/caddy/*.access.log /etc/fail2ban/filter.d/caddy.conf`.
4. **Rate limit logins** (`Caddyfile.j2`): append
   `&p=github.com%2Fmholt%2Fcaddy-ratelimit` to the Caddy download URL in
   `roles/caddy/tasks/main.yml`; add a login-scoped `rate_limit` (60s / ~20 events
   per `{remote_host}{host}{path}`) for auth paths.
5. **Tighten attack-path matchers** (`Caddyfile.j2`): review `/admin/*`, `/data/*`,
   `/files/*`, `/status`, `/logs/*` against real app routes; prefer
   `respond @attack_paths 403` where apps need a body; keep `abort` for `.env`/`.git`.
6. **Home Caddy admin** (`services/caddy/local/docker-compose.yml`): set
   `admin 127.0.0.1:2019`; the local otel scraper uses `caddy:2019` in-network, so
   the `2019:2019` host publish can go.

**Verify:** `nmap -Pn -p 22,80,443,2019 <vps>` → 2019 closed; brute force throttled;
smoke list of real app URLs returns expected codes.

### Phase 3 — Network segmentation (P0)

**Goal:** edge compromise ≠ full homelab access.

1. Checked-in `infrastructure/tailscale/acls.hujson` (apply via provider or console),
   tagged, deny-by-default:

   ```jsonc
   {
     "tagOwners": { "tag:edge": ["autogroup:admin"], "tag:home": ["autogroup:admin"] },
     "acls": [
       { "action": "accept", "src": ["tag:edge"],
         "dst": ["tag:home:22300","tag:home:10500","tag:home:9111",
                 "tag:home:2007","tag:home:2008","tag:home:8050",
                 "tag:home:18600","tag:home:4553","tag:home:22"] },
       { "action": "accept", "src": ["autogroup:admin"], "dst": ["*:*"] }
     ]
   }
   ```

   Remove the default allow-all. Tag `vps` `tag:edge`; home servers `tag:home`.
2. Scope `--advertise-routes` to only what the edge needs, or keep the LAN unrouted
   from the edge and proxy to overlay IPs.
3. Enable **Tailscale SSH** for admin access to tagged hosts.

**Verify:** edge can reach only proxied ports; a non-listed home port fails; admin
device retains full access; `server1/2/3` proxying still works.

### Phase 4 — Authorization layer (P0/P1)

Put **authentik** (already running) in front of *private-ish* public apps via Caddy
`forward_auth`; keep truly public apps open.

- Snippet `(authentik_auth)` in `Caddyfile.j2` (align URI with authentik Caddy
  outpost docs):

  ```caddyfile
  forward_auth http://{{ server2 }}.{{ caddy_domain }}:9000 {
      uri /outpost.goauthentik.io/auth/caddy
      copy_headers X-authentik-username X-authentik-email X-authentik-groups
  }
  ```

- Apply to Forgejo, Joplin, Nextcloud, *arr UIs, `gatus`, `grafana`, `prom.`,
  `uptime-kuma`. Leave open: `n.` (ntfy), `paste.`/`public.`, `mempool.`, `music.`.
- Add authentik itself to the edge config with a login rate limit.

**Verify:** protected host redirects to authentik and returns; public hosts
stay 200; ntfy publish with token still works.

### Phase 5 — Host integrity / IDS (P1)

New role `roles/host-ids` on `vps` + home server:

- `auditd` rules: `execve` (key `exec`); writes to
  `/etc/{passwd,shadow,sudoers,ssh/authorized_keys}`, `/usr/bin/caddy`, `/etc/caddy`,
  `/var/run/docker.sock`; systemd unit changes.
- `aide` (`aideinit`; daily `aide --check` timer) with volatile paths excluded;
  diff alerts → ntfy.
- `rkhunter` weekly `--cronjob` → ntfy.
- Ship auditd + journald off-box.
- Optional Tier 2: **CrowdSec** (bouncer + caddy/sshd collections) on `vps` + home;
  notifications → ntfy; note CAPI privacy trade-off (opt-out available).
- Cover the KVM/IoT class from the GL.iNet incident.

**Verify:** modify a monitored file / run a tracked binary → aide/auditd alert;
`cscli decisions list` shows bans and the bouncer blocks.

### Phase 6 — Supply chain (P1)

1. **Pin images to digests** for security-relevant services; start with telegraf,
   otel collectors, grafana; verify the Caddy binary download with `checksum:`.
2. **Watchtower**: notify on update (`WATCHTOWER_NOTIFICATION_URL` → ntfy), consider
   `--monitor-only`, and move rw `docker.sock` behind `tecnativa/docker-socket-proxy`
   (see `docker-host.md`).

**Verify:** notification fires on a forced pull; socket-proxy allowlist is narrow.

### Phase 7 — Cloudflare decision (P1)

- **Proxy on**: WAF/Bot Fight/DDoS, hides origin. Requires Caddy `trusted_proxies`
  (CF IP ranges) and the Phase 2.3 `client_ip` filter change; harden the CF account
  (2FA, scoped token, rotation). Privacy cost: CF terminates TLS and sees all domains.
- **Stay grey**: keep aggressive fail2ban/CrowdSec; document the choice.
- Either way rotate `cloudflare_api_token` (can rewrite the zone + issue certs).

**Verify:** if proxied, ban lists show real client IPs, not CF IPs; ACME still renews.

### Phase 8 — Backups & secrets (P1)

- Make the offsite repo **append-only** (restic/borg `--append-only` over SSH, or
  dated rsync snapshots) so a compromised source can't wipe history.
- Backup success/failure → ntfy + healthchecks; test a restore.
- Ensure `alertmanager-ntfy/config.yml` token never lands in git raw; keep
  `vault.yml` untracked + SOPS-backed; rotate ntfy + OTEL tokens; scope OTLP token.

**Verify:** delete a file in source → restore from offsite; remote is append-only.

### Phase 9 — CI / periodic (P2)

- Add Trivy/Grype image+dependency scan to `.pre-commit-config.yaml` / CI.
- One-off `docker bench`/CIS triage; quarterly `lynis audit system` on `vps` + home.

### Phase 10 — Close-out

- Run `roles/caddy/files/validate-security.sh` + the smoke list.
- `homelab-logbook` entry; update `roles/caddy/SECURITY.md`; mark phases `done`.

## 6. Rollback

- Everything is Ansible/Compose; use `--check` then apply. Keep changes one
  phase at a time so a bad apply is reversible.
- **Phase 3 is the lockout risk**: apply ACLs in the console first, verify from a
  second device, keep the VPS provider web console before disabling allow-all.
- **Phase 2.2**: confirm key access before disabling password auth.
- **Phase 7**: `trusted_proxies` and the filter change ship together.

## 7. Open questions / decisions

1. Cloudflare proxy vs grey — Phase 7 blocker.
2. ~~logwatch digest: ntfy vs installing an MTA~~ **Answered 2026-11-25:**
   ntfy, via a systemd timer in `roles/base` (`dd53d34`). No MTA: the only thing
   that wants mail on these hosts is logwatch itself.
3. CrowdSec now or fail2ban+otel first (recommend the latter, then evaluate).
4. ~~Does `*.local.<domain>` resolve publicly?~~ **Answered 2026-11-25:** no.
   `*.local.<domain>` resolves to `192.168.1.178` (LAN Caddy), so otel/grafana/
   prom are LAN-only and need LAN auth, not public authz. Only the wildcard
   `*.<domain>` vhost on the VPS is internet-facing.
5. Are `vault.yml` and the age key recoverable if the laptop dies?
6. Any Alpine/musl host for `cve-2026-123158`?
7. fail2ban → Prometheus: add a real exporter (`fail2ban_exporter` container) for
   dashboards, or settle for ntfy-on-ban plus `fail2ban-client` on demand? The
   dashboard in 1.7 wants history; the alerts do not strictly need it.
8. **Proxmox `8006` — parked 2026-11-26.** ufw denies it for everyone (284
   drops seen, including local-caddy `.178`), so `pve1.local.<domain>` and
   direct access are both dead. Choices: allow `.178`, allow `.152`, allow the
   LAN, or keep it closed and use `ssh -L 8006:127.0.0.1:8006`. Not the LAN
   option: the PVE API is root-equivalent. Before enabling the `pve1` vhost,
   check its `cache` directive in front of an authenticated UI. It belongs in a
   `proxmox_firewall` role, not `node_exporter`.
9. **gatus — parked 2026-11-26.** Two faults: the publisher has no write ACL on
   `alerts` (403 three times a minute), and its probes lie — `gitea.<domain>` is
   gone from the edge Caddyfile, so the probe hits the catch-all `abort`
   (status 0), and `music.`'s probe URL is still unread. Either disable the
   publisher, or fix the live config and then grant write. Never grant write
   before the probes are truthful. The live config is not in git and the repo
   copy is a stale subset that would delete checks if deployed.

## 8. References

- Caddy `reverse_proxy` / `trusted_proxies` / XFF — <https://caddyserver.com/docs/caddyfile/directives/reverse_proxy>
- Caddy `forward_auth` — <https://caddyserver.com/docs/caddyfile/directives/forward_auth>
- Tailscale ACLs (deny-by-default; default is allow-all) — <https://tailscale.com/kb/1018/acls>
- CrowdSec Caddy collection — <https://hub.crowdsec.net/author/crowdsecurity/collections/caddy>
- Cloudflare IP ranges — <https://www.cloudflare.com/ips/>
- fail2ban — <https://github.com/fail2ban/fail2ban>
- AIDE — <https://aide.github.io/> ; `auditd(8)`
