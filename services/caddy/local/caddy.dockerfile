ARG CADDY_VERSION

# https://hub.docker.com/_/caddy
FROM caddy:${CADDY_VERSION}-builder AS builder

RUN xcaddy build \
	  --with github.com/caddyserver/certmagic \
    --with github.com/caddyserver/nginx-adapter \
    --with github.com/caddy-dns/cloudflare \
    --with github.com/caddyserver/cache-handler \
    --with github.com/darkweak/storages/otter/caddy

# https://github.com/caddyserver/caddy/releases/
FROM caddy:${CADDY_VERSION}

COPY --from=builder /usr/bin/caddy /usr/bin/caddy
