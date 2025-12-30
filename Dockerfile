FROM iboates/osm2pgsql:latest

USER root

# Debian/Ubuntu base en général
RUN apt-get update \
  && apt-get install -y --no-install-recommends curl ca-certificates postgresql-client coreutils \
  && rm -rf /var/lib/apt/lists/*

# Revenir à un user non-root si l'image le permet, sinon tu restes root
# (et tu relies à runAsUser=1000 côté K8S)
USER 1000:1000

ENTRYPOINT ["/bin/sh", "-c"]
