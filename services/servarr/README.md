# servarr

Media automation stack: Prowlarr, Sonarr, Radarr, Lidarr, Bazarr and
Dispatcharr. Deployed to the `server` host with `just deploy` (Docker context
`server-docker`).

All media lives on the NAS over NFS; the containers themselves keep state under
`$BASE_DIR`.

## Services

| Service    | Host port | Purpose                                   |
| ---------- | --------- | ----------------------------------------- |
| prowlarr   | 9696      | indexer manager                           |
| sonarr     | 8989      | TV series                                 |
| radarr     | 7878      | movies                                    |
| lidarr     | 8686      | music                                     |
| bazarr     | 6767      | subtitles                                 |
| dispatcharr| 9191      | IPTV streams, EPG and DVR                 |

`readarr` is retired upstream (2025); see the commented block in
`docker-compose.yml` for the maintained fork.

## URLs

Every service is reverse-proxied by local-caddy at
`https://<service>.local.<domain>` (prowlarr, sonarr, radarr, lidarr, bazarr,
dispatcharr). None of them use Caddy's `cache`, since the UIs are
authenticated and dynamic.

## Deploy

```sh
just deploy     # set docker context, scp config dirs, compose up -d
just update     # pull new images
just logs       # follow logs
```

## Dispatcharr

Dispatcharr consolidates IPTV playlists, matches EPG data, proxies streams and
emulates an HDHomeRun tuner so Jellyfin can consume live TV and record to its
own DVR library.

It runs in **AIO** mode: PostgreSQL and Redis are bundled inside the single
container. State lives in `$BASE_DIR/dispatcharr/data` (`db/`, `cache/`,
`logs/`, plus the generated `jwt` secret) and must be included in backups.

Reachable at `https://dispatcharr.local.<domain>` via local-caddy.

### First-run setup

The first-time setup page only accepts POSTs from local/private networks, which
covers the LAN. If you ever need to bootstrap from another address, either:

```sh
docker compose exec dispatcharr python manage.py createsuperuser
```

or set `DISPATCHARR_SETUP_ALLOWED_IP` to the client IP before starting.

### Endpoints

| Path          | Auth           | Use                                  |
| ------------- | -------------- | ------------------------------------ |
| `/`           | yes            | web UI                               |
| `/hdhr/`      | no             | HDHomeRun discovery (Jellyfin tuner) |
| `/output/m3u` | no             | playlist, every channel              |
| `/output/epg` | no             | guide (EPG), every channel           |
| `get.php`     | XC credentials | per-user playlist                    |
| `xmltv.php`   | XC credentials | per-user guide                       |

`/output/m3u`, `/output/epg` and `/hdhr/` take no credentials and cannot be
revoked per user. They are only reachable on the LAN (the `local.` zone does not
resolve publicly), but restrict them under
**Settings → Network Access** if that ever changes. For sharing, prefer the
`get.php` / `xmltv.php` forms, which carry a revocable username and password.

### Timezone

`TZ` is deliberately the local zone (`America/New_York` from `.env`), not the
`Etc/UTC` the `*arr` services use, because DVR schedules and the EPG grid are
rendered in it.

### Resources

uWSGI runs 2 workers and Celery autoscales 1–3, alongside PostgreSQL and Redis,
so the container is limited to 2 CPU / 2G. Transcoding is not enabled; add
`devices: [/dev/dri:/dev/dri]` and `group_add: [video]` if you want VA-API
acceleration.
