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

# Choose your data source:
# Option 1: Geofabrik (default)
OSM_DATA_URL=https://download.geofabrik.de/europe/france-latest.osm.pbf

# Option 2: Scaleway S3 (faster for European regions, recommended)
# OSM_DATA_URL=https://osm.s3.fr-par.scw.cloud/pbf/europe/france-latest.osm.pbf

OSM_DATA_FILE=data.osm.pbf
```

**Data Sources:**
- **Geofabrik**: Official OSM extracts, updated daily
- **Scaleway S3**: High-performance mirror hosted on Scaleway infrastructure, optimized for European regions with faster download speeds

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

##### Simple Job Deployment

Deploy a one-time import job:

```bash
kubectl apply -f k8s-manifest.yml
```

See `k8s-manifest.yml` for the complete example manifest.

##### Production CronJob for Europe Rebuild

For production use with automatic weekly rebuilds of all European countries:

```bash
kubectl apply -f k8s-cronjob-europe.yml
```

The CronJob (`k8s-cronjob-europe.yml`) provides:
- **Scheduled execution**: Runs weekly on Sundays (8th-16th of month) at 1 AM Paris time
- **Sequential processing**: Downloads and imports all 47 European countries
- **Checkpoint system**: Resumes from last successful country on failure
- **Parallel downloads**: Uses 8-part parallel downloads for faster transfers
- **Resource optimization**: 12GB cache, 3 processes for osm2pgsql
- **Production-ready**: Includes proper security context, resource limits, and error handling

Required ConfigMaps and Secrets:
- `osm-sync-secrets`: PostgreSQL connection details (PGHOST, PGPORT, PGDATABASE, PGUSER, PGPASSWORD)
- `osm-flex-addresses`: ConfigMap containing `osm-flex-addresses.lua` style file
- `osm-refresh-sql`: ConfigMap containing `refresh_osm_addresses.sql` script
- `osm-work-pvc`: PersistentVolumeClaim for working directory

Quick deployment example:

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

## OSM Data Sources

The pipeline supports multiple data sources for OpenStreetMap data:

### 1. Geofabrik (Official)

The official OSM extract service, updated daily:

```bash
# Example URLs
https://download.geofabrik.de/europe/france-latest.osm.pbf
https://download.geofabrik.de/europe/germany-latest.osm.pbf
https://download.geofabrik.de/north-america/us-latest.osm.pbf
```

**Pros:**
- Official and trusted source
- Wide geographic coverage worldwide
- Daily updates

**Cons:**
- Can be slower depending on your location
- Limited bandwidth during peak times

Browse available extracts: https://download.geofabrik.de/

### 2. Scaleway S3 (Recommended for Europe)

High-performance OSM data mirror hosted on Scaleway infrastructure:

```bash
# Example URLs
https://osm.s3.fr-par.scw.cloud/pbf/europe/france-latest.osm.pbf
https://osm.s3.fr-par.scw.cloud/pbf/europe/germany-latest.osm.pbf
https://osm.s3.fr-par.scw.cloud/pbf/europe/albania-latest.osm.pbf
```

**Pros:**
- Very fast downloads (especially in European regions)
- High bandwidth and low latency
- Supports HTTP range requests for parallel downloads
- Used by the production CronJob for optimal performance

**Cons:**
- Primarily optimized for European data
- May have different update schedules than Geofabrik

**Available regions:**
- Europe: `https://osm.s3.fr-par.scw.cloud/pbf/europe/{country}-latest.osm.pbf`
- See k8s-cronjob-europe.yml for the complete list of available European countries

### Choosing a Data Source

For development and testing:
```bash
# Small extract (Monaco) from Geofabrik
OSM_DATA_URL=https://download.geofabrik.de/europe/monaco-latest.osm.pbf

# Or from Scaleway
OSM_DATA_URL=https://osm.s3.fr-par.scw.cloud/pbf/europe/monaco-latest.osm.pbf
```

For production (European regions):
```bash
# Use Scaleway S3 for best performance
OSM_DATA_URL=https://osm.s3.fr-par.scw.cloud/pbf/europe/france-latest.osm.pbf
```

For production (other regions):
```bash
# Use Geofabrik for worldwide coverage
OSM_DATA_URL=https://download.geofabrik.de/north-america/us-latest.osm.pbf
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
      # Use Scaleway S3 for faster downloads (recommended)
      OSM_DATA_URL: https://osm.s3.fr-par.scw.cloud/pbf/europe/monaco-latest.osm.pbf
      # Or use Geofabrik:
      # OSM_DATA_URL: https://download.geofabrik.de/europe/monaco-latest.osm.pbf
      OSM_DATA_FILE: /data/monaco.osm.pbf
    volumes:
      - ./data:/data
      - ./scripts:/scripts
    command: /scripts/run-pipeline.sh

volumes:
  postgres_data:
```

## Kubernetes Manifests

The repository includes four Kubernetes manifests for production deployment:

### 1. k8s-resources.yml (Required Foundation)

Complete Kubernetes resources including all dependencies:

**Components:**
- **Namespace**: `osm` namespace for all OSM resources
- **Secret**: `osm-sync-secrets` with PostgreSQL connection details
  - Host, port, database, credentials
  - SSL mode and connection parameters
  - Keepalive settings for stable connections
- **PersistentVolumeClaim**: `osm-work-pvc` (100Gi) for working directory
- **ConfigMap**: `osm-flex-addresses` with Lua style for osm2pgsql
  - Extracts address data from OSM nodes and ways
  - Creates `osm_addr_point` and `osm_addr_area` tables
- **ConfigMap**: `osm-refresh-sql` with SQL refresh script
  - Consolidates address data into unified table
  - Generates searchable labels with unaccent support

**First-time setup:**
```bash
# Edit the secret with your PostgreSQL credentials
vim k8s-resources.yml

# Apply the resources
kubectl apply -f k8s-resources.yml
```

**Important:** Update the Secret with your actual PostgreSQL credentials before deploying:
```yaml
stringData:
  PGHOST: "your-postgres-host.example.com"
  PGPORT: "5432"
  PGDATABASE: "osm"
  PGUSER: "your-username"
  PGPASSWORD: "your-secure-password"
```

### 2. k8s-manifest.yml

A complete deployment example with:
- PostgreSQL/PostGIS StatefulSet with persistent storage
- One-time Job for OSM data import
- Secrets and ConfigMaps for configuration
- Proper security contexts (non-root, capability drops)

Deploy with:
```bash
kubectl apply -f k8s-manifest.yml
```

### 3. k8s-europe.yml

One-time Job for manual European data rebuild (all 47 countries):

**Features:**
- **Coverage**: All 47 European countries from Scaleway S3
- **Smart Downloads**: Parallel 8-part downloads with range requests from Scaleway S3
- **Checkpoint System**: Resumes from last successful country on failure
- **Resource Limits**: 12Gi memory, 8 CPUs max, with proper requests/limits
- **Database Schema**: Automatic creation of OSM addresses table with indexes
- **Security**: Runs as non-root (UID 1000), drops all capabilities, seccomp profile
- **Duration**: Up to 48h allowed for complete Europe rebuild

**Use Cases:**
- Manual one-time import of all European countries
- Testing the import pipeline before enabling the CronJob
- Recovery after errors or system issues

Deploy manually:
```bash
kubectl apply -f k8s-europe.yml
```

Monitor progress:
```bash
# Watch job status
kubectl get job osm-europe-rebuild -n osm -w

# View logs
kubectl logs -n osm -l app.kubernetes.io/name=osm-europe-rebuild -f --tail=100
```

### 4. k8s-cronjob-europe.yml

Production-grade CronJob for automated European data rebuilds:

**Features:**
- **Schedule**: Weekly on Sundays (8th-16th) at 1 AM Paris time
- **Coverage**: All 47 European countries from Scaleway S3
- **Smart Downloads**: Parallel 8-part downloads with range requests
- **Checkpoint System**: Resumes from last successful country on failure
- **Resource Limits**: 12Gi memory, 8 CPUs max, with proper requests/limits
- **Database Schema**: Automatic creation of OSM addresses table with indexes
- **Security**: Runs as non-root (UID 1000), drops all capabilities, seccomp profile

**Prerequisites:**

All required resources are defined in `k8s-resources.yml`. Simply apply it first:

```bash
# Edit with your PostgreSQL credentials
vim k8s-resources.yml

# Apply all resources (namespace, secrets, PVC, ConfigMaps)
kubectl apply -f k8s-resources.yml
```

Deploy the CronJob:
```bash
kubectl apply -f k8s-cronjob-europe.yml
```

Monitor the job:
```bash
# List CronJobs
kubectl get cronjobs -n osm

# Watch running jobs
kubectl get jobs -n osm -w

# View logs
kubectl logs -n osm -l app.kubernetes.io/name=osm-europe-rebuild --tail=100 -f
```

## Complete Kubernetes Deployment Guide

### Step-by-Step Production Setup

1. **Prepare your PostgreSQL database**
   - Ensure PostGIS extension is available
   - Create database and user with appropriate permissions

2. **Deploy base resources**
   ```bash
   # Edit k8s-resources.yml with your PostgreSQL credentials
   vim k8s-resources.yml
   
   # Apply: creates namespace, secrets, PVC, and ConfigMaps
   kubectl apply -f k8s-resources.yml
   ```

3. **Verify resources**
   ```bash
   # Check namespace
   kubectl get namespace osm
   
   # Check secret
   kubectl get secret osm-sync-secrets -n osm
   
   # Check PVC
   kubectl get pvc osm-work-pvc -n osm
   
   # Check ConfigMaps
   kubectl get configmap -n osm
   ```

4. **Test with a manual Job**
   ```bash
   # Deploy one-time Europe rebuild job
   kubectl apply -f k8s-europe.yml
   
   # Monitor progress
   kubectl logs -n osm -l app.kubernetes.io/name=osm-europe-rebuild -f
   ```

5. **Enable automated rebuilds (optional)**
   ```bash
   # Deploy CronJob for weekly automatic rebuilds
   kubectl apply -f k8s-cronjob-europe.yml
   ```

### Troubleshooting

**Check Job status:**
```bash
kubectl get jobs -n osm
kubectl describe job osm-europe-rebuild -n osm
```

**View Pod logs:**
```bash
# Get pod name
kubectl get pods -n osm

# View logs
kubectl logs -n osm <pod-name> -c europe-sequential-runner -f
```

**Check PostgreSQL connection:**
```bash
# Test connection from a debug pod
kubectl run -n osm psql-test --rm -it --image=postgres:15 -- \
  psql -h <PGHOST> -U <PGUSER> -d <PGDATABASE>
```

**Cleanup failed jobs:**
```bash
# Delete failed job to retry
kubectl delete job osm-europe-rebuild -n osm

# Reapply
kubectl apply -f k8s-europe.yml
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