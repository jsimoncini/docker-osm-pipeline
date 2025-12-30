#!/bin/sh
set -e

# Complete OSM pipeline: download and import
# Usage: ./run-pipeline.sh

SCRIPT_DIR="$(dirname "$0")"

echo "=== OSM Pipeline Starting ==="

# Step 1: Download OSM data
echo ""
echo "Step 1: Downloading OSM data..."
"$SCRIPT_DIR/download-osm-data.sh"

# Step 2: Import into PostgreSQL
echo ""
echo "Step 2: Importing OSM data into PostgreSQL..."
"$SCRIPT_DIR/import-osm-data.sh"

echo ""
echo "=== OSM Pipeline Complete ==="
