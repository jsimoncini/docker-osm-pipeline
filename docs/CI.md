# Documentation de la Pipeline CI

Ce document décrit en détail la pipeline CI/CD du projet docker-osm-pipeline.

## Vue d'ensemble

La pipeline CI est implémentée avec GitHub Actions et effectue les tâches suivantes :

1. **Lint** - Vérification de la qualité du code
2. **Build** - Construction de l'image Docker multi-architecture
3. **Test** - Tests de l'image construite
4. **Security Scan** - Analyse de sécurité avec Trivy
5. **Push** - Publication vers GitHub Container Registry (optionnel)

## Déclencheurs

La pipeline se déclenche sur :

- **Push** vers les branches `main` et `develop`
- **Tags** commençant par `v*` (ex: v1.0.0)
- **Pull Requests** vers `main` et `develop`
- **Manuel** via workflow_dispatch

## Jobs de la Pipeline

### 1. Job: Lint

**Objectif:** Vérifier la qualité et la conformité du code

**Étapes:**

1. **Lint Dockerfile (hadolint)**
   - Outil: [hadolint](https://github.com/hadolint/hadolint)
   - Vérifie les bonnes pratiques Docker
   - Seuil d'échec: warning
   - Exemples de vérifications:
     - Utilisation de versions spécifiques
     - Ordre optimal des instructions
     - Sécurité des commandes

2. **Lint Shell Scripts**
   - Vérification de la syntaxe avec `sh -n`
   - Valide tous les scripts dans `scripts/`
   - Détecte les erreurs de syntaxe

3. **Lint YAML**
   - Outil: yamllint
   - Configuration: mode relaxed
   - Limite de longueur de ligne: 120 caractères
   - Vérifie: docker-compose.yml, k8s-*.yml, etc.

**En cas d'échec:**
- Vérifiez les messages d'erreur dans les logs
- Corrigez localement avec `make lint`
- Commitez les corrections

### 2. Job: Build and Test

**Objectif:** Construire et tester l'image Docker

**Dépendances:** Job `lint` doit réussir

**Étapes:**

1. **Setup Docker Buildx**
   - Active les fonctionnalités avancées de build
   - Permet le build multi-architecture
   - Configure le cache GitHub Actions

2. **Build Image**
   - Construction de l'image de test
   - Utilisation du cache GHA pour accélérer
   - Tag: `osm-pipeline:test`
   - Platforms: linux/amd64 (pour les tests)

3. **Test Image**
   - Vérification de la taille de l'image
   - Test de présence des outils:
     - curl
     - psql (PostgreSQL client)
     - osm2pgsql
   - Vérification de l'utilisateur (UID 1000)

4. **Vulnerability Scan (Trivy)**
   - Outil: [Trivy](https://github.com/aquasecurity/trivy)
   - Scan des vulnérabilités CRITICAL et HIGH
   - Format de sortie: SARIF
   - Upload vers GitHub Security tab
   - Continue même en cas d'échec (if: always())

**En cas d'échec:**
- Build: vérifiez le Dockerfile et les dépendances
- Tests: vérifiez que tous les packages sont installés
- Vulnérabilités: consultez la Security tab

### 3. Job: Build and Push

**Objectif:** Construire et publier l'image multi-architecture

**Dépendances:** Job `build-and-test` doit réussir

**Condition:** Ne s'exécute PAS sur les Pull Requests

**Étapes:**

1. **Setup QEMU**
   - Émulation pour builds multi-architecture
   - Permet de builder pour arm64 sur amd64

2. **Setup Docker Buildx**
   - Configuration pour build multi-plateforme

3. **Login to GitHub Container Registry**
   - Registry: ghcr.io
   - Username: acteur GitHub
   - Token: GITHUB_TOKEN (automatique)

4. **Extract Metadata**
   - Génère les tags automatiquement:
     - `main` → `latest`
     - `develop` → `develop`
     - `v1.2.3` → `1.2.3`, `1.2`, `1`, `latest`
     - `sha-abc123` → `main-abc123`

5. **Build and Push**
   - Platforms: linux/amd64, linux/arm64
   - Push vers ghcr.io
   - Utilise le cache GHA

6. **Generate Attestation**
   - Génère une attestation de provenance
   - Améliore la sécurité de la supply chain

## Secrets Requis

### GITHUB_TOKEN (Automatique)

- **Type:** Automatiquement fourni par GitHub Actions
- **Usage:** 
  - Login vers ghcr.io
  - Upload des résultats de scan de sécurité
- **Permissions requises:**
  - `contents: read`
  - `packages: write`

**Aucune configuration manuelle requise** - GitHub Actions fournit ce token automatiquement.

### Secrets Optionnels

Si vous souhaitez pousser vers un autre registry:

```yaml
# Dans .github/workflows/ci.yml
env:
  REGISTRY: docker.io  # ou autre registry
  
# Dans les secrets du repo:
DOCKER_USERNAME: votre-username
DOCKER_PASSWORD: votre-token
```

## Configuration des Permissions

Pour activer la publication d'images:

1. Aller dans **Settings** → **Actions** → **General**
2. Section **Workflow permissions**
3. Sélectionner **Read and write permissions**
4. Cocher **Allow GitHub Actions to create and approve pull requests**

## Exécution Locale

### Prérequis

```bash
# Ubuntu/Debian
sudo apt-get install make docker.io hadolint yamllint

# macOS
brew install make docker hadolint yamllint
```

### Commandes Makefile

```bash
# Aide
make help

# Linting
make lint                # Tous les linters
make lint-dockerfile     # Dockerfile seulement
make lint-shell         # Scripts shell seulement
make lint-yaml          # YAML seulement

# Build
make build-local        # Build local simple
make build-multiarch    # Build multi-arch (nécessite buildx)

# Test
make test-image         # Test de l'image

# Pipeline complète
make ci-run             # Exécute lint + build + test

# Nettoyage
make clean              # Supprime images et cache
```

### Exemple d'exécution complète

```bash
# Clone le repo
git clone https://github.com/your-org/docker-osm-pipeline.git
cd docker-osm-pipeline

# Configuration dev
make dev-setup

# Build et test
make ci-run

# Si tout passe, l'image est prête
docker images osm-pipeline:latest
```

## Déboguer la Pipeline

### Problème: Lint Dockerfile échoue

**Symptômes:**
```
DL3008 warning: Pin versions in apt-get install
```

**Solutions:**
1. Consulter [hadolint rules](https://github.com/hadolint/hadolint#rules)
2. Corriger le Dockerfile
3. Tester localement: `make lint-dockerfile`

### Problème: Build échoue

**Symptômes:**
```
ERROR: failed to solve: process "/bin/sh -c apt-get update" did not complete successfully
```

**Solutions:**
1. Vérifier que l'image de base existe
2. Vérifier les noms des packages
3. Tester localement: `make build-local`

### Problème: Tests échouent

**Symptômes:**
```
which: no osm2pgsql in (PATH)
```

**Solutions:**
1. Vérifier que l'image de base contient osm2pgsql
2. Vérifier le PATH
3. Tester manuellement:
   ```bash
   docker run --rm osm-pipeline:test "which osm2pgsql"
   ```

### Problème: Push échoue (Permission denied)

**Symptômes:**
```
denied: permission_denied
```

**Solutions:**
1. Vérifier les permissions du workflow (Settings → Actions)
2. Vérifier que GITHUB_TOKEN a les permissions `packages: write`
3. Pour les organisations, vérifier les paramètres de package visibility

### Problème: Multi-arch build lent

**Cause:** L'émulation ARM64 sur AMD64 est lente

**Solutions:**
1. C'est normal, soyez patient
2. Utilisez le cache GHA (déjà configuré)
3. Pour dev local, buildez uniquement pour votre arch:
   ```bash
   make build-local  # Plus rapide
   ```

## Optimisations

### Cache Docker Layer

La pipeline utilise le cache GitHub Actions:

```yaml
cache-from: type=gha
cache-to: type=gha,mode=max
```

**Avantages:**
- Accélère les builds (5-10x plus rapide)
- Réduit la bande passante
- Partagé entre les runs

### Build Matrix (Optionnel)

Pour tester sur plusieurs versions:

```yaml
strategy:
  matrix:
    base-image:
      - iboates/osm2pgsql:latest
      - iboates/osm2pgsql:1.9.0
```

## Monitoring

### Visualiser les runs

1. Onglet **Actions** du repo
2. Sélectionner un workflow run
3. Voir les logs détaillés de chaque job

### Notifications

GitHub envoie des emails en cas d'échec si:
- Vous êtes l'auteur du commit
- Vous êtes propriétaire du repo

### Badges

Ajoutez au README:

```markdown
![CI](https://github.com/owner/docker-osm-pipeline/workflows/CI%20Pipeline/badge.svg)
```

## Sécurité

### Scan de Vulnérabilités

Trivy scanne:
- Vulnérabilités OS
- Vulnérabilités de packages
- Misconfigurations

**Consulter les résultats:**
1. Onglet **Security** du repo
2. Section **Code scanning alerts**

### Best Practices

- ✅ Images de base officielles
- ✅ Versions épinglées des dépendances
- ✅ Utilisateur non-root
- ✅ Scan de vulnérabilités automatique
- ✅ Attestation de provenance
- ✅ Secrets via GitHub Secrets

## Maintenance

### Mise à jour des Actions

Vérifiez régulièrement:

```bash
# Liste des actions utilisées
grep "uses:" .github/workflows/ci.yml
```

Mettez à jour vers les dernières versions:
- `actions/checkout@v4`
- `docker/build-push-action@v5`
- etc.

### Retention des Images

GitHub Container Registry:
- Images non taguées: supprimées après 14 jours
- Images taguées: conservées indéfiniment

**Nettoyage manuel:**
1. Aller dans **Packages**
2. Sélectionner le package
3. Supprimer les anciennes versions

## Support

Pour toute question:

1. Consultez la [documentation GitHub Actions](https://docs.github.com/en/actions)
2. Ouvrez une issue sur le repo
3. Consultez les logs détaillés des runs

## Ressources

- [GitHub Actions](https://docs.github.com/en/actions)
- [Docker Buildx](https://docs.docker.com/buildx/working-with-buildx/)
- [Hadolint](https://github.com/hadolint/hadolint)
- [Trivy](https://github.com/aquasecurity/trivy)
- [GHCR](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)
