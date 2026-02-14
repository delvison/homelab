ARG CADDY_VERSION

# https://hub.docker.com/_/caddy
FROM caddy:${CADDY_VERSION}-builder AS builder

# Configure Go for better network resilience
ENV GOPROXY=https://proxy.golang.org,direct
ENV GOSUMDB=sum.golang.org
ENV GOFLAGS="-buildvcs=false"

RUN xcaddy build \
	  --with github.com/caddyserver/certmagic \
    --with github.com/caddyserver/nginx-adapter \
    --with github.com/caddy-dns/cloudflare \
    --with github.com/caddyserver/cache-handler \
    --with github.com/darkweak/storages/otter/caddy || \
    (sleep 5 && xcaddy build \
	  --with github.com/caddyserver/certmagic \
    --with github.com/caddyserver/nginx-adapter \
    --with github.com/caddy-dns/cloudflare \
    --with github.com/caddyserver/cache-handler \
    --with github.com/darkweak/storages/otter/caddy) || \
    (sleep 10 && xcaddy build \
	  --with github.com/caddyserver/certmagic \
    --with github.com/caddyserver/nginx-adapter \
    --with github.com/caddy-dns/cloudflare \
    --with github.com/caddyserver/cache-handler \
    --with github.com/darkweak/storages/otter/caddy)

# https://github.com/caddyserver/caddy/releases/
FROM caddy:${CADDY_VERSION}

COPY --from=builder /usr/bin/caddy /usr/bin/caddy

RUN mkdir -p /etc/caddy /var/log/caddy && \
    chown -R 1000:1000 /etc/caddy /var/log/caddy /data /config
