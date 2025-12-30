# docker-osm-pipeline

[![CI Pipeline](https://github.com/jsimoncini/docker-osm-pipeline/workflows/CI%20Pipeline/badge.svg)](https://github.com/jsimoncini/docker-osm-pipeline/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Pipeline Docker pour le traitement de données OpenStreetMap (OSM) avec osm2pgsql.

[English Documentation](README.md)

## 📋 Table des matières

- [Vue d'ensemble](#vue-densemble)
- [Fonctionnalités](#fonctionnalités)
- [Prérequis](#prérequis)
- [Installation rapide](#installation-rapide)
- [Build local](#build-local)
- [Sources de données](#sources-de-données)
- [Déploiement](#déploiement)
- [CI/CD](#cicd)
- [Contribution](#contribution)
- [License](#license)

## 🎯 Vue d'ensemble

Ce projet fournit une infrastructure complète pour traiter des données OpenStreetMap :

- **Dockerfile** optimisé basé sur `iboates/osm2pgsql:latest`
- **Scripts** de téléchargement et d'import automatisés
- **Support Scaleway S3** pour des téléchargements rapides en Europe
- **Manifests Kubernetes** production-ready avec Job et CronJob
- **Pipeline CI/CD** complète avec GitHub Actions

## ✨ Fonctionnalités

- ✅ Image Docker sécurisée (utilisateur non-root UID 1000)
- ✅ Support multi-sources : Geofabrik et Scaleway S3
- ✅ Téléchargements parallèles (8 parties) via HTTP range requests
- ✅ Système de checkpoints pour reprise sur erreur
- ✅ Manifests Kubernetes avec sécurité renforcée
- ✅ CronJob pour rebuild automatique de l'Europe (47 pays)
- ✅ CI/CD multi-architecture (amd64, arm64)
- ✅ Scan de vulnérabilités automatique avec Trivy
- ✅ Documentation complète en français

## 📦 Prérequis

### Pour utilisation locale

- Docker 20.10+
- PostgreSQL 12+ avec extension PostGIS
- 100 Go d'espace disque (pour données Europe complète)

### Pour Kubernetes

- Cluster Kubernetes 1.24+
- kubectl configuré
- PostgreSQL managé avec PostGIS (recommandé)
- StorageClass avec support ReadWriteOnce

### Pour développement

- Make
- hadolint (optionnel, pour lint Dockerfile)
- yamllint (optionnel, pour lint YAML)

## 🚀 Installation rapide

### 1. Cloner le repository

```bash
git clone https://github.com/jsimoncini/docker-osm-pipeline.git
cd docker-osm-pipeline
```

### 2. Configuration

```bash
# Copier le fichier d'exemple
cp .env.example .env

# Éditer avec vos paramètres
vim .env
```

Configurez vos paramètres PostgreSQL et source de données :

```bash
# PostgreSQL
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DB=osm
POSTGRES_USER=osmuser
POSTGRES_PASSWORD=votre-mot-de-passe

# Source de données (Scaleway S3 recommandé pour l'Europe)
OSM_DATA_URL=https://osm.s3.fr-par.scw.cloud/pbf/europe/france-latest.osm.pbf
OSM_DATA_FILE=data.osm.pbf
```

### 3. Lancer avec Docker Compose

```bash
docker-compose up
```

## 🔨 Build local

### Avec Make (recommandé)

```bash
# Configuration environnement de développement
make dev-setup

# Build de l'image
make build-local

# Tests
make test-image

# Lint
make lint

# Pipeline CI complète en local
make ci-run
```

### Avec Docker directement

```bash
# Build
docker build -t osm-pipeline:latest .

# Test de l'image
docker run --rm osm-pipeline:latest "osm2pgsql --version"
```

### Build multi-architecture

```bash
# Nécessite Docker Buildx
docker buildx create --use
make build-multiarch
```

## 🌍 Sources de données

### Scaleway S3 (Recommandé pour l'Europe)

**Avantages :**
- 🚀 Téléchargements très rapides depuis l'Europe
- 📦 Support des HTTP range requests (téléchargements parallèles)
- 🔄 Utilisé par le CronJob de production

**Format d'URL :**
```
https://osm.s3.fr-par.scw.cloud/pbf/europe/{pays}-latest.osm.pbf
```

**Exemples :**
```bash
# France
https://osm.s3.fr-par.scw.cloud/pbf/europe/france-latest.osm.pbf

# Allemagne
https://osm.s3.fr-par.scw.cloud/pbf/europe/germany-latest.osm.pbf

# Albanie
https://osm.s3.fr-par.scw.cloud/pbf/europe/albania-latest.osm.pbf
```

### Geofabrik (Source officielle)

**Avantages :**
- ✅ Source officielle et fiable
- 🌍 Couverture mondiale
- 📅 Mises à jour quotidiennes

**Format d'URL :**
```
https://download.geofabrik.de/{région}/{pays}-latest.osm.pbf
```

**Exemples :**
```bash
# Europe
https://download.geofabrik.de/europe/france-latest.osm.pbf

# Amérique du Nord
https://download.geofabrik.de/north-america/us-latest.osm.pbf

# Asie
https://download.geofabrik.de/asia/japan-latest.osm.pbf
```

## 🚢 Déploiement

### Docker

```bash
# Télécharger des données
docker run --rm \
  --env-file .env \
  -v $(pwd)/data:/data \
  osm-pipeline:latest \
  "/scripts/download-osm-data.sh"

# Importer dans PostgreSQL
docker run --rm \
  --env-file .env \
  -v $(pwd)/data:/data \
  --network host \
  osm-pipeline:latest \
  "/scripts/import-osm-data.sh /data/data.osm.pbf"
```

### Kubernetes - Guide complet

#### 1. Déployer les ressources de base

```bash
# Éditer avec vos identifiants PostgreSQL
vim k8s-resources.yml

# Appliquer : crée namespace, secrets, PVC, ConfigMaps
kubectl apply -f k8s-resources.yml
```

#### 2. Vérifier les ressources

```bash
# Namespace
kubectl get namespace osm

# Secret
kubectl get secret osm-sync-secrets -n osm

# PVC
kubectl get pvc osm-work-pvc -n osm

# ConfigMaps
kubectl get configmap -n osm
```

#### 3. Import manuel (test)

```bash
# Lancer un Job unique pour l'Europe
kubectl apply -f k8s-europe.yml

# Suivre les logs
kubectl logs -n osm -l app.kubernetes.io/name=osm-europe-rebuild -f
```

#### 4. Activer le rebuild automatique

```bash
# Déployer le CronJob (hebdomadaire)
kubectl apply -f k8s-cronjob-europe.yml

# Vérifier le CronJob
kubectl get cronjobs -n osm
```

### Fichiers Kubernetes disponibles

| Fichier | Description | Usage |
|---------|-------------|-------|
| `k8s-resources.yml` | Ressources de base (namespace, secrets, PVC, ConfigMaps) | **Requis en premier** |
| `k8s-manifest.yml` | Exemple de déploiement simple | Développement/test |
| `k8s-europe.yml` | Job unique pour rebuild Europe (47 pays) | Exécution manuelle |
| `k8s-cronjob-europe.yml` | CronJob hebdomadaire pour Europe | Production |

## 🔄 CI/CD

### Pipeline GitHub Actions

La pipeline CI s'exécute automatiquement sur :

- ✅ Push vers `main` et `develop`
- ✅ Tags `v*` (ex: v1.0.0)
- ✅ Pull Requests
- ✅ Déclenchement manuel

**Étapes de la pipeline :**

1. **Lint** - Vérification qualité code
   - Dockerfile (hadolint)
   - Scripts shell (syntax)
   - Fichiers YAML (yamllint)

2. **Build & Test** - Construction et tests
   - Build image Docker
   - Tests fonctionnels
   - Scan vulnérabilités (Trivy)

3. **Push** - Publication (si non-PR)
   - Build multi-architecture (amd64, arm64)
   - Push vers GitHub Container Registry
   - Génération d'attestation de provenance

### Configuration des secrets

**Aucune configuration requise !** 

La pipeline utilise automatiquement `GITHUB_TOKEN` fourni par GitHub Actions.

### Exécution locale de la CI

```bash
# Toute la pipeline
make ci-run

# Ou étape par étape
make lint
make build-local
make test-image
```

### Documentation complète

Consultez [docs/CI.md](docs/CI.md) pour :
- 📖 Description détaillée de chaque job
- 🔧 Guide de configuration
- 🐛 Troubleshooting
- 📊 Monitoring et optimisations

## 🤝 Contribution

Les contributions sont les bienvenues !

### Comment contribuer

1. **Fork** le projet
2. **Créer** une branche feature (`git checkout -b feature/AmazingFeature`)
3. **Commit** vos changements (`git commit -m 'Add some AmazingFeature'`)
4. **Push** vers la branche (`git push origin feature/AmazingFeature`)
5. **Ouvrir** une Pull Request

### Standards de code

- ✅ Exécuter `make lint` avant de commit
- ✅ Tester localement avec `make ci-run`
- ✅ Documenter les nouvelles fonctionnalités
- ✅ Ajouter des tests si pertinent

### Signaler un bug

Utilisez les [Issue Templates](.github/ISSUE_TEMPLATE/) :
- 🐛 **Bug Report** - Pour signaler un problème
- ✨ **Feature Request** - Pour proposer une fonctionnalité

## 📚 Documentation

### Structure du projet

```
docker-osm-pipeline/
├── .github/
│   ├── workflows/
│   │   └── ci.yml              # Pipeline CI/CD
│   └── ISSUE_TEMPLATE/         # Templates d'issues
├── docs/
│   └── CI.md                   # Documentation CI détaillée
├── scripts/
│   ├── download-osm-data.sh    # Téléchargement OSM
│   ├── import-osm-data.sh      # Import PostgreSQL
│   └── run-pipeline.sh         # Pipeline complète
├── Dockerfile                   # Image Docker
├── docker-compose.yml          # Setup développement
├── Makefile                    # Commandes utiles
├── k8s-resources.yml           # Ressources K8s de base
├── k8s-europe.yml              # Job Europe manuel
├── k8s-cronjob-europe.yml      # CronJob Europe auto
├── k8s-manifest.yml            # Exemple K8s simple
├── .env.example                # Configuration exemple
├── .gitignore                  # Fichiers ignorés
├── LICENSE                     # Licence MIT
├── README.md                   # Documentation (EN)
└── README.fr.md                # Documentation (FR)
```

### Liens utiles

- 📖 [Documentation CI/CD complète](docs/CI.md)
- 🐳 [Docker Hub - osm2pgsql](https://hub.docker.com/r/iboates/osm2pgsql)
- 🗺️ [OpenStreetMap](https://www.openstreetmap.org/)
- 📥 [Geofabrik Downloads](https://download.geofabrik.de/)
- 🔧 [osm2pgsql Documentation](https://osm2pgsql.org/)
- 🗄️ [PostGIS](https://postgis.net/)

## ⚙️ Configuration avancée

### Optimisation des performances

**Pour imports volumineux (Europe complète) :**

```bash
# Dans .env ou variables d'environnement
OSM2PGSQL_CACHE=12000         # 12 Go de cache
OSM2PGSQL_NUM_PROCESSES=8     # 8 processus parallèles
DL_PARTS=8                    # 8 parties pour téléchargement
```

**PostgreSQL (recommandations) :**

```sql
-- Optimisations pour import
SET synchronous_commit = off;
SET maintenance_work_mem = '2GB';
SET checkpoint_completion_target = 0.9;
```

### Personnalisation du style osm2pgsql

Le fichier `osm-flex-addresses.lua` dans `k8s-resources.yml` peut être modifié pour extraire d'autres données :

```lua
-- Exemple : ajouter des POIs
local pois = osm2pgsql.define_table{
  name = 'osm_pois',
  schema = 'osm',
  ids = { type = 'node', id_column = 'osm_id' },
  columns = {
    { column = 'name', type = 'text' },
    { column = 'amenity', type = 'text' },
    { column = 'geom', type = 'point', projection = 4326 }
  }
}
```

## 🐛 Dépannage

### Problème : Download échoue

```bash
# Vérifier la connectivité
curl -I https://osm.s3.fr-par.scw.cloud/pbf/europe/monaco-latest.osm.pbf

# Tester avec Geofabrik
OSM_DATA_URL=https://download.geofabrik.de/europe/monaco-latest.osm.pbf
```

### Problème : Import PostgreSQL échoue

```bash
# Vérifier la connexion
psql -h $POSTGRES_HOST -U $POSTGRES_USER -d $POSTGRES_DB -c "SELECT version();"

# Vérifier PostGIS
psql -h $POSTGRES_HOST -U $POSTGRES_USER -d $POSTGRES_DB -c "SELECT PostGIS_version();"
```

### Problème : Job Kubernetes bloqué

```bash
# Voir les événements
kubectl describe job osm-europe-rebuild -n osm

# Voir les logs du pod
kubectl logs -n osm $(kubectl get pods -n osm -l app.kubernetes.io/name=osm-europe-rebuild -o name) -f

# Supprimer et relancer
kubectl delete job osm-europe-rebuild -n osm
kubectl apply -f k8s-europe.yml
```

## 📊 Monitoring

### Métriques importantes

- **Temps de téléchargement** : ~2-10 min par pays (selon taille)
- **Temps d'import** : Variable selon données et matériel
- **Espace disque** : ~100 Go pour Europe complète
- **Mémoire** : 12-24 Go recommandés pour imports volumineux

### Logs

```bash
# Docker
docker logs <container-id> -f

# Kubernetes
kubectl logs -n osm -l app.kubernetes.io/name=osm-europe-rebuild -f --tail=100

# Suivre un pays spécifique
kubectl logs -n osm <pod-name> -f | grep "\[country\]"
```

## 📄 License

Ce projet est sous licence MIT - voir le fichier [LICENSE](LICENSE) pour plus de détails.

## 🙏 Remerciements

- [OpenStreetMap](https://www.openstreetmap.org/) - Source de données
- [osm2pgsql](https://osm2pgsql.org/) - Outil d'import
- [Geofabrik](https://www.geofabrik.de/) - Extraits OSM
- [Scaleway](https://www.scaleway.com/) - Hébergement S3
- Tous les contributeurs du projet

## 📞 Support

- 📧 Ouvrir une [Issue](https://github.com/jsimoncini/docker-osm-pipeline/issues)
- 💬 Discussions dans [GitHub Discussions](https://github.com/jsimoncini/docker-osm-pipeline/discussions)
- 📖 Consulter la [Documentation](docs/)

---

**Fait avec ❤️ pour la communauté OSM**
