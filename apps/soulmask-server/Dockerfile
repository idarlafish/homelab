# Soulmask dedicated server image.
#
# Built on cm2network/steamcmd (Debian, amd64). Installs the native Linux
# Soulmask dedicated server (Steam app 3017300) at image build time so pods
# boot quickly without re-downloading ~5 GB on every cold start.
#
# Build & push:
#   docker buildx build --platform linux/amd64 \
#     -t ghcr.io/idarlafish/soulmask-server:latest --push apps/soulmask-server/

FROM cm2network/steamcmd:latest

# Unreal Engine runtime deps that slim Debian bases sometimes omit.
USER root
RUN apt-get update \
 && apt-get install -y --no-install-recommends libatomic1 \
 && rm -rf /var/lib/apt/lists/*

USER steam
WORKDIR /home/steam

# Install Soulmask dedicated server (native Linux build, app id 3017300).
RUN /home/steam/steamcmd/steamcmd.sh \
      +force_install_dir /home/steam/soulmask \
      +login anonymous \
      +app_update 3017300 validate \
      +quit

COPY --chown=steam:steam entrypoint.sh /home/steam/entrypoint.sh
RUN chmod +x /home/steam/entrypoint.sh

EXPOSE 27050/udp 27051/udp 25575/tcp

ENTRYPOINT ["/home/steam/entrypoint.sh"]
