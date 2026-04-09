# Soulmask dedicated server image.
#
# Minimal: just SteamCMD (via cm2network/steamcmd), libatomic1 (Unreal
# runtime dep), and entrypoint.sh. The actual Soulmask binaries are not
# baked into the image — entrypoint.sh downloads them to the PVC on every
# pod start via SteamCMD, so the server auto-updates to the latest build
# whenever the pod restarts. Set SKIP_UPDATE=1 to pin a version.
#
# Build & push (one-time, rarely rebuilt):
#   docker buildx build --platform linux/amd64 \
#     -t ghcr.io/idarlafish/soulmask-server:latest --push apps/soulmask-server/

FROM cm2network/steamcmd:latest

# Unreal Engine runtime deps that slim Debian bases sometimes omit.
USER root
RUN apt-get update \
 && apt-get install -y --no-install-recommends libatomic1 procps \
 && rm -rf /var/lib/apt/lists/*

USER steam
WORKDIR /home/steam

COPY --chown=steam:steam entrypoint.sh /home/steam/entrypoint.sh
RUN chmod +x /home/steam/entrypoint.sh

EXPOSE 27050/udp 27051/udp 25575/tcp

ENTRYPOINT ["/home/steam/entrypoint.sh"]
