# Phase 2 — edge hardening (2026-11-26)

Status: **code written, deploy pending.** The VPS is reachable only with the
YubiKey/passphrase and `just run-caddy` asks for the sudo password, so the
deploy is a manual step (see below). Nothing here has been applied to the VPS.

Scope: the public host only (`vps`, ansible user `npc`, SSH on **2245**). The
SSH port is **not changed**: ufw allows 2245 and 22. The LAN hosts are out of
scope: a default-deny firewall there would cut Grafana `:3000`, Prometheus
`:9090`, node exporters and the rest.

## What was true before this phase

- `caddy_server.yaml` runs `caddy` + `otelcol`; `roles/base` **never** runs on
  the VPS. Anything the plan puts in `roles/base` misses the one public host.
  Hardening therefore lives in `roles/caddy`, following the same decision as
  the fail2ban jails (plan §1.2).
- The VPS Caddyfile already binds `admin 127.0.0.1:2019`.
- The home Caddy publishes `2019:2019` to the LAN while binding the admin API
  to `0.0.0.0` inside the container. Its scraper (`otelcol` sidecar) reaches
  `caddy:2019` over the compose network, so the host publish is what must go,
  not the container binding.
- The fail2ban filters matched only `remote_ip`. With `trusted_proxies` the
  real client is in `client_ip`, so a ban would hit the proxy.
- `rate_limit` was not compiled into the Caddy binary; the Caddyfile carried a
  note saying so.

## Changes

| # | Item | File | State |
|---|---|---|---|
| 2.1 | ufw: allow every port `sshd -T` reports, 80/443 tcp, 443 udp (HTTP/3), default deny incoming, allow outgoing, enable | `roles/caddy/tasks/main.yml` | written |
| 2.2 | sshd: keys only, no root login, no keyboard-interactive, `MaxAuthTries 3`, no X11; `sshd -T` asserts the result, then `sshd -t` + reload | `roles/caddy/templates/sshd-hardening.conf.j2` + tasks | written |
| 2.3 | fail2ban: match `client_ip` before `remote_ip` in both filters (first match wins); verified with `fail2ban-regex -o ip` | `caddy-filter.conf.j2`, `caddy-envscan-filter.conf.j2` | written |
| 2.4 | `caddy-ratelimit` added to the custom binary; login paths limited to 20 events/60 s per client+host+path. Syntax validated against a real v2.11.9 binary with both plugins | `roles/caddy/tasks/main.yml`, `Caddyfile.j2` | written |
| 2.5 | Attack-path matchers reviewed against real app routes | — | **not done** — needs the app list; see below |
| 2.6 | Home Caddy: drop the `2019:2019` host publish, keep the admin bound inside the container | `services/caddy/local/docker-compose.yml` | written |

The ufw rule reads the live SSH port from `sshd -T` instead of the distro
default; a name-based `OpenSSH` rule allows 22 and would cut the session. The
`caddy_ssh_port` default (22) is unioned in, so both 22 and the live port (2245
today) stay open. Nothing in the role writes a `Port` line; the port is
unchanged. The variable is the fallback for the socket-activation case, where
`sshd -T` reports the default while the socket listens elsewhere.

## Deploy

```sh
cd infrastructure/ansible
ansible-playbook -i inventory.ini caddy_server.yaml -K      # full play
# or one tag at a time:
just run-caddy
```

The Caddy handler already runs `caddy validate` before `systemctl restart`, so
a bad Caddyfile aborts the restart and leaves the old process serving. The sshd
task runs `sshd -T` and asserts the effective values, then `sshd -t` before
`systemctl reload ssh` — and it runs every time, so fixing a missing `Include`
and re-running actually applies the drop-in.

The home Caddy publish is a separate stack:

```sh
cd services/caddy/local && just deploy
```

`--force-recreate` restarts pihole and the collector too, so DNS and proxying
blip for a few seconds. After it is up, `local-caddy.md` in the vault needs its
port table and admin note updated.

Before running: confirm a second key login works, and keep the provider web
console open. If ufw locks SSH, the console is the way back in
(`ufw allow 2245/tcp`).

## Verify

```sh
nmap -Pn -p 22,80,443,2019,2245 <vps>      # only 80, 443, 2245 open
ssh vps 'sudo sshd -T | grep -E "^(passwordauthentication|permitrootlogin|maxauthtries|x11forwarding)"'
ssh vps 'sudo ufw status verbose'
# 21 login POSTs in a minute from one client -> 429, then a fail2ban ban
```

Also check `Caddy429Burst` in the plan's alerts now has a possible source, and
that a legitimate login still works from a phone on a different network.

## 2.5 — what is left

`@attack_paths` blocks `/admin/*`, `/data/*`, `/files/*`, `/upload*`,
`/download*`, `/export*`, `/import*`, `/status`, `/logs/*` for every host. Some
are real app routes (a file app, an admin UI). The check is: for each app, pick
one real path under those prefixes and see whether it returns the app or 403.
Where an app needs a body, switch that matcher from `abort` to
`respond 403`; keep `abort` for `.env`, `.git` and dotfiles. Do not guess —
a wrong change here breaks a working app.

## Rollback

- ufw: `sudo ufw disable` (console if SSH is cut).
- sshd: remove `/etc/ssh/sshd_config.d/99-hardening.conf`, `systemctl reload ssh`.
- Caddy: `git revert` the role change and re-run the play; the old binary is
  replaced by the same download step.
- Home Caddy: restore the `2019:2019` mapping and `up -d caddy`.

## Open

- Cloudflare proxying (Phase 7) changes `remote_host` to a CF edge address.
  Until `trusted_proxies` is set, the rate-limit key is per CF PoP, not per
  client. Revisit the 20/min number then.
- 2.5 needs the list of app routes; parked with the method above.
