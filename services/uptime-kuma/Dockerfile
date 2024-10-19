FROM louislam/uptime-kuma:1-alpine

RUN --mount=type=cache,target=/var/cache/apk apk add --no-cache tor==0.4.4.9-r0

RUN echo '#!/bin/sh' > /bin/entrypoint.sh && \
    echo 'tor &' >> /bin/entrypoint.sh && \
    echo '/usr/bin/dumb-init -- extra/entrypoint.sh node server/server.js' >> /bin/entrypoint.sh &&\
    chmod +x /bin/entrypoint.sh

ENTRYPOINT ["/bin/entrypoint.sh"]
