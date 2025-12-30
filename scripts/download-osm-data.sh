#!/bin/sh
set -e

# Script to download OSM data
# Usage: ./download-osm-data.sh <url> <output-file>

URL="${1:-${OSM_DATA_URL}}"
OUTPUT="${2:-${OSM_DATA_FILE}}"

if [ -z "$URL" ]; then
    echo "Error: OSM data URL not provided"
    echo "Usage: $0 <url> <output-file>"
    exit 1
fi

echo "Downloading OSM data from: $URL"
echo "Output file: $OUTPUT"

curl -L -o "$OUTPUT" "$URL"

echo "Download complete: $OUTPUT"
ls -lh "$OUTPUT"
