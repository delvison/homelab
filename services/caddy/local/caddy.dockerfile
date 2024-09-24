FROM caddy:2.8.4-builder AS builder

RUN xcaddy build \
	  --with github.com/caddyserver/certmagic \
    --with github.com/caddyserver/nginx-adapter \
    --with github.com/caddy-dns/cloudflare

FROM caddy:2.8.4

COPY --from=builder /usr/bin/caddy /usr/bin/caddy
