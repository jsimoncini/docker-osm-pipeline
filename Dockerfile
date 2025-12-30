FROM iboates/osm2pgsql:2.2.0

USER root

# Alpine base - install required packages
# hadolint ignore=DL3018
RUN apk add --no-cache --update postgresql-client

# Switch back to non-root user if the image allows, otherwise stay root
# (and use runAsUser=1000 on K8S side)
USER 1000:1000

ENTRYPOINT ["/bin/sh", "-c"]
