# vim: ft=dockerfile
FROM python:3.11-slim-bookworm

ARG NETBIRD_VERSION=0.74.7
LABEL version="0.74.7"
LABEL org.opencontainers.image.source="https://github.com/ixian-ukraine/blueos-extension-netbird"

# NetBird's Debian package postinst calls systemctl, which doesn't exist in a
# container. A no-op shim lets the install succeed; we run the daemon ourselves
# via `netbird service run` in the entrypoint (no systemd needed).
RUN printf '#!/bin/sh\nexit 0\n' > /usr/local/bin/systemctl && chmod +x /usr/local/bin/systemctl

# Install NetBird from its official APT repo (pinned) + web UI runtime deps.
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends ca-certificates curl gnupg && \
    curl -sSL https://pkgs.netbird.io/debian/public.key \
      | gpg --dearmor --output /usr/share/keyrings/netbird-archive-keyring.gpg && \
    echo 'deb [signed-by=/usr/share/keyrings/netbird-archive-keyring.gpg] https://pkgs.netbird.io/debian stable main' \
      > /etc/apt/sources.list.d/netbird.list && \
    apt-get update -qq && \
    apt-get install -y --no-install-recommends "netbird=${NETBIRD_VERSION}" && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Keep config on the persistent bind mount (/var/lib/netbird) — the daemon is
# pointed at it via `netbird service run --config=…` in the entrypoint. The apt
# package otherwise defaults config to /etc/netbird/config.json, which is NOT
# persisted across restarts/updates.
ENV NB_LOG_FILE=console

COPY entrypoint.sh /entrypoint.sh
RUN chmod 755 /entrypoint.sh

COPY web /web
RUN cd web && pip install --no-cache-dir .

LABEL permissions='\
{\
    "NetworkMode":"host"\
    ,"HostConfig":{\
        "Privileged": true,\
        "NetworkMode":"host",\
        "CapAdd":["SYS_ADMIN","NET_ADMIN"],\
        "Binds":["/usr/blueos/extensions/nb-vpn:/var/lib/netbird"],\
        "Devices":[\
            {\
                "PathOnHost":"/dev/net/tun",\
                "PathInContainer":"/dev/net/tun",\
                "CgroupPermissions":"rwm"\
            }\
        ]\
    }\
}'
LABEL authors='[\
    {\
        "name": "Pinnokio",\
        "email": "pinnokio@users.noreply.github.com"\
    }\
]'
LABEL company='{\
        "about": "NetBird VPN integration for BlueOS",\
        "name": "Ixian Ukraine"\
    }'
LABEL type="other"
LABEL tags='[\
        "communication"\
    ]'
LABEL readme='https://raw.githubusercontent.com/ixian-ukraine/blueos-extension-netbird/{tag}/README.md'
LABEL links='{\
        "website": "https://github.com/ixian-ukraine/blueos-extension-netbird",\
        "support": "https://github.com/ixian-ukraine/blueos-extension-netbird/issues"\
    }'
LABEL requirements="core >= 1.1"

HEALTHCHECK --interval=10s CMD bash /healthcheck.sh

CMD []
ENTRYPOINT ["/entrypoint.sh"]
