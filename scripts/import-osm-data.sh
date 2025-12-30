#!/bin/sh
set -e

# Script to import OSM data into PostgreSQL using osm2pgsql
# Usage: ./import-osm-data.sh <osm-file>

OSM_FILE="${1:-${OSM_DATA_FILE}}"
DB_HOST="${POSTGRES_HOST:-localhost}"
DB_PORT="${POSTGRES_PORT:-5432}"
DB_NAME="${POSTGRES_DB:-osm}"
DB_USER="${POSTGRES_USER:-osmuser}"
DB_PASS="${POSTGRES_PASSWORD:-}"
CACHE="${OSM2PGSQL_CACHE:-2048}"
PROCS="${OSM2PGSQL_NUM_PROCESSES:-4}"

if [ -z "$OSM_FILE" ]; then
    echo "Error: OSM data file not provided"
    echo "Usage: $0 <osm-file>"
    exit 1
fi

if [ ! -f "$OSM_FILE" ]; then
    echo "Error: File not found: $OSM_FILE"
    exit 1
fi

echo "Importing OSM data from: $OSM_FILE"
echo "Database: $DB_HOST:$DB_PORT/$DB_NAME"
echo "Cache: ${CACHE}MB"
echo "Processes: $PROCS"

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL..."
export PGPASSWORD="$DB_PASS"
until pg_isready -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER"; do
    echo "PostgreSQL is unavailable - sleeping"
    sleep 2
done
echo "PostgreSQL is ready"

# Run osm2pgsql with password from environment
osm2pgsql \
    --create \
    --slim \
    --drop \
    --cache "$CACHE" \
    --number-processes "$PROCS" \
    --host "$DB_HOST" \
    --port "$DB_PORT" \
    --database "$DB_NAME" \
    --username "$DB_USER" \
    --hstore \
    --multi-geometry \
    "$OSM_FILE"

echo "Import complete"
