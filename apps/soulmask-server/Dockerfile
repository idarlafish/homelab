# Soulmask dedicated server image.
#
# Self-contained: the image bundles supercronic for in-container scheduled
# tasks (auto-reboot, etc.) plus a small set of orchestration scripts.
# Following the pattern of thijsvanloef/palworld-server-docker, everything
# operational lives inside the image — the k8s (or docker-compose) side is
# just a dumb consumer that sets env vars and runs the container.
#
# Build & push (one-time; only rebuild on Dockerfile or script changes):
#   docker buildx build --platform linux/amd64 \
#     -t ghcr.io/idarlafish/soulmask-server:latest --push apps/soulmask-server/

FROM cm2network/steamcmd:latest

# Unreal Engine runtime deps + procps (pgrep for liveness probe) +
# ca-certificates (needed by supercronic's github-raw fetches and generally) +
# tini (used as PID 1 — see ENTRYPOINT below).
USER root
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      libatomic1 procps ca-certificates curl tini \
 && rm -rf /var/lib/apt/lists/*

# supercronic — cron daemon that plays well with containers (logs via
# stdout, forwards signals, no systemd / syslog needed).
# Pin version + sha1 so rebuilds are reproducible and supply-chain-safe.
ARG SUPERCRONIC_VERSION=v0.2.44
ARG SUPERCRONIC_URL=https://github.com/aptible/supercronic/releases/download/${SUPERCRONIC_VERSION}/supercronic-linux-amd64
ARG SUPERCRONIC_SHA1=6eb0a8e1e6673675dc67668c1a9b6409f79c37bc
RUN curl -fsSL "$SUPERCRONIC_URL" -o /usr/local/bin/supercronic \
 && echo "${SUPERCRONIC_SHA1}  /usr/local/bin/supercronic" | sha1sum -c - \
 && chmod +x /usr/local/bin/supercronic

USER steam
WORKDIR /home/steam

# Orchestration scripts live in /home/steam/scripts/. init.sh is the
# container entrypoint (PID 1); it traps SIGTERM, backgrounds start.sh
# and supercronic, and waits.
COPY --chown=steam:steam scripts/ /home/steam/scripts/
RUN chmod +x /home/steam/scripts/*.sh

EXPOSE 27050/udp 27051/udp 25575/tcp

# tini is PID 1: reaps zombies and forwards signals correctly to children.
# init.sh does the app-level orchestration underneath.
ENTRYPOINT ["/usr/bin/tini", "--", "/home/steam/scripts/init.sh"]
