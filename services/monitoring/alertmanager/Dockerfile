FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    gettext=0.21-12 \
    curl=7.88.1-10+deb12u5 \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -u 1000 -s /bin/sh alertmanager

RUN curl -L -o /tmp/alertmanager.tar.gz \
    https://github.com/prometheus/alertmanager/releases/download/v0.27.0/alertmanager-0.27.0.linux-amd64.tar.gz && \
    tar -xzf /tmp/alertmanager.tar.gz -C /tmp && \
    mv /tmp/alertmanager-0.27.0.linux-amd64/alertmanager /usr/local/bin/ && \
    mv /tmp/alertmanager-0.27.0.linux-amd64/amtool /usr/local/bin/ && \
    rm -rf /tmp/alertmanager* && \
    mkdir -p /alertmanager && \
    chown -R alertmanager:alertmanager /alertmanager

COPY --chown=alertmanager:alertmanager alertmanager.template.yml /etc/alertmanager/alertmanager.template.yml

USER alertmanager

VOLUME /alertmanager

ENTRYPOINT ["/bin/sh", "-c"]

CMD ["envsubst < /etc/alertmanager/alertmanager.template.yml > /etc/alertmanager/alertmanager.yml && alertmanager --config.file=/etc/alertmanager/alertmanager.yml --storage.path=/alertmanager"]