# docker-osm-pipeline

A Docker-based pipeline for processing OpenStreetMap (OSM) data using osm2pgsql.

## Overview

This project provides a complete scaffold for an OSM data processing pipeline that:
- Downloads OSM data from any source (e.g., Geofabrik)
- Imports the data into a PostgreSQL database using osm2pgsql
- Runs in a containerized environment with Docker/Kubernetes

## Features

- Based on `iboates/osm2pgsql:latest` Docker image
- Includes all necessary dependencies (curl, PostgreSQL client, coreutils)
- Runs as non-root user (UID 1000) for security
- Ready for Kubernetes deployment
- Complete set of processing scripts

## Prerequisites

- Docker
- PostgreSQL database (local or remote)
- OSM data file or URL to download from

## Quick Start

### 1. Configuration

Copy the example environment file and customize it:

```bash
cp .env.example .env
```

Edit `.env` with your PostgreSQL credentials and OSM data source:

```bash
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DB=osm
POSTGRES_USER=osmuser
POSTGRES_PASSWORD=osmpassword

OSM_DATA_URL=https://download.geofabrik.de/europe/france-latest.osm.pbf
OSM_DATA_FILE=data.osm.pbf
```

### 2. Build the Docker Image

```bash
docker build -t osm-pipeline .
```

### 3. Run the Pipeline

#### Using Docker

Download OSM data:
```bash
docker run --rm \
  --env-file .env \
  -v $(pwd)/data:/data \
  osm-pipeline \
  "/scripts/download-osm-data.sh"
```

Import data to PostgreSQL:
```bash
docker run --rm \
  --env-file .env \
  -v $(pwd)/data:/data \
  --network host \
  osm-pipeline \
  "/scripts/import-osm-data.sh /data/data.osm.pbf"
```

#### Using Docker Compose

Create a `docker-compose.yml` file (see example below) and run:

```bash
docker-compose up
```

#### Using Kubernetes

Deploy with the following manifest (adjust as needed):

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: osm-import
spec:
  template:
    spec:
      securityContext:
        runAsUser: 1000
        runAsGroup: 1000
      containers:
      - name: osm-pipeline
        image: osm-pipeline:latest
        command: ["/bin/sh", "-c", "/scripts/run-pipeline.sh"]
        env:
        - name: POSTGRES_HOST
          value: "postgres-service"
        - name: POSTGRES_DB
          value: "osm"
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: username
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: password
        - name: OSM_DATA_URL
          value: "https://download.geofabrik.de/europe/monaco-latest.osm.pbf"
        volumeMounts:
        - name: data
          mountPath: /data
      restartPolicy: Never
      volumes:
      - name: data
        emptyDir: {}
```

## Scripts

### download-osm-data.sh

Downloads OSM data from a URL.

```bash
./scripts/download-osm-data.sh <url> <output-file>
```

Environment variables:
- `OSM_DATA_URL`: URL to download from
- `OSM_DATA_FILE`: Output filename

### import-osm-data.sh

Imports OSM data into PostgreSQL using osm2pgsql.

```bash
./scripts/import-osm-data.sh <osm-file>
```

Environment variables:
- `POSTGRES_HOST`: PostgreSQL host (default: localhost)
- `POSTGRES_PORT`: PostgreSQL port (default: 5432)
- `POSTGRES_DB`: Database name (default: osm)
- `POSTGRES_USER`: Database user (default: osmuser)
- `POSTGRES_PASSWORD`: Database password
- `OSM2PGSQL_CACHE`: Cache size in MB (default: 2048)
- `OSM2PGSQL_NUM_PROCESSES`: Number of processes (default: 4)

### run-pipeline.sh

Runs the complete pipeline (download + import).

```bash
./scripts/run-pipeline.sh
```

## Docker Image Details

The Dockerfile is based on `iboates/osm2pgsql:latest` and includes:

- **Base Image**: `iboates/osm2pgsql:latest` (includes osm2pgsql)
- **Additional Packages**:
  - `curl`: For downloading OSM data
  - `ca-certificates`: For HTTPS support
  - `postgresql-client`: For database operations
  - `coreutils`: Standard utilities
- **Security**: Runs as user 1000:1000 (non-root)
- **Entrypoint**: `/bin/sh -c` for flexible command execution

## Example: Docker Compose Setup

```yaml
version: '3.8'

services:
  postgres:
    image: postgis/postgis:latest
    environment:
      POSTGRES_DB: osm
      POSTGRES_USER: osmuser
      POSTGRES_PASSWORD: osmpassword
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

  osm-pipeline:
    build: .
    depends_on:
      - postgres
    environment:
      POSTGRES_HOST: postgres
      POSTGRES_PORT: 5432
      POSTGRES_DB: osm
      POSTGRES_USER: osmuser
      POSTGRES_PASSWORD: osmpassword
      OSM_DATA_URL: https://download.geofabrik.de/europe/monaco-latest.osm.pbf
      OSM_DATA_FILE: /data/monaco.osm.pbf
    volumes:
      - ./data:/data
      - ./scripts:/scripts
    command: /scripts/run-pipeline.sh

volumes:
  postgres_data:
```

## License

MIT

## Contributing

Pull requests are welcome! For major changes, please open an issue first to discuss what you would like to change.

## Resources

- [OpenStreetMap](https://www.openstreetmap.org/)
- [osm2pgsql Documentation](https://osm2pgsql.org/)
- [Geofabrik Downloads](https://download.geofabrik.de/)
- [PostGIS](https://postgis.net/)