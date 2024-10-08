# https://hub.docker.com/_/caddy
FROM caddy:2.8.4-builder AS builder

RUN xcaddy build \
	  --with github.com/caddyserver/certmagic \
    --with github.com/caddyserver/nginx-adapter \
    --with github.com/caddy-dns/cloudflare \
    --with github.com/caddyserver/cache-handler \
    --with github.com/darkweak/storages/otter/caddy

FROM caddy:2.8.4

COPY --from=builder /usr/bin/caddy /usr/bin/caddy
