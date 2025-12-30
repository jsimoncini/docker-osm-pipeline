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

if [ -z "$OUTPUT" ]; then
    echo "Error: Output file not specified"
    echo "Usage: $0 <url> <output-file>"
    exit 1
fi

echo "Downloading OSM data from: $URL"
echo "Output file: $OUTPUT"

curl -L --fail --show-error --max-time 7200 --retry 3 --retry-delay 5 -o "$OUTPUT" "$URL"

if [ ! -s "$OUTPUT" ]; then
    echo "Error: Downloaded file '$OUTPUT' is missing or empty"
    rm -f "$OUTPUT"
    exit 1
fi
echo "Download complete: $OUTPUT"
ls -lh "$OUTPUT"
