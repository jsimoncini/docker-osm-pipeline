FROM iboates/osm2pgsql:2.2.0

USER root

# Debian/Ubuntu base - install required packages
# hadolint ignore=DL3008
RUN apt-get update \
  && apt-get install -y --no-install-recommends curl ca-certificates postgresql-client coreutils \
  && rm -rf /var/lib/apt/lists/*

# Switch back to non-root user if the image allows, otherwise stay root
# (and use runAsUser=1000 on K8S side)
USER 1000:1000

ENTRYPOINT ["/bin/sh", "-c"]
