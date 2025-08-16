# SmartRent Deploy

GitOps deployment configuration for SmartRent AI application using ArgoCD and Sealed Secrets.

## 🏗️ Project Structure

```bash
smartrent-deploy/
├── apps/                           # ArgoCD Applications
│   └── dev-application.yaml       # Development environment app
├── charts/smartrent/               # Helm Chart
│   ├── templates/                  # Kubernetes manifests
│   │   ├── ai.yaml                # AI service deployment
│   │   ├── backend.yaml           # Backend service deployment
│   │   ├── ingress.yaml           # Ingress configuration
│   │   └── secrets.yaml           # ConfigMaps and Secrets
│   ├── environments/              # Environment-specific configs
│   │   └── dev/
│   │       ├── values.yaml        # Dev environment values
│   │       └── sealed-secrets.yaml # Encrypted secrets for dev
│   └── values.yaml                # Default Helm values
├── config/                        # Infrastructure configs
│   └── argocd-ingress.yaml       # ArgoCD ingress
├── scripts/                       # Helper scripts
│   ├── manage-secrets             # Sealed secrets management
│   └── setup.sh                   # Environment setup script
└── Makefile                       # Task runner
```

## 🚀 Quick Start

### Prerequisites
- Kubernetes cluster
- ArgoCD installed
- Sealed Secrets controller installed

### Setup

Use the task runner to set up the environment:
```bash
make setup
```

Or manually install the Sealed Secrets controller:
```bash
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml
```

### Apply ArgoCD Application
```bash
kubectl apply -f apps/dev-application.yaml
```
Or use the task runner:
```bash
make apply-dev
```

### Managing Secrets

```bash
# List current secrets
make secret-list

# Add new secret
make create-secret NAME=API_KEY VALUE=your-secret-value

# Update existing secret
make update-secret NAME=MYSQL_PASSWORD VALUE=new-password
```

### Environment Variables
Your application uses these environment variables:
- `MYSQL_PASSWORD` - Database password (sealed secret)
- `MYSQL_SERVER` - Database server (config)
- `MYSQL_USER` - Database username (config)
- `MYSQL_DB` - Database name (config)
- `MYSQL_PORT` - Database port (config)
- `ENVIRONMENT` - Environment name (config)
- `DEBUG` - Debug mode flag (config)
- `VERSION` - Application version (config)

## 🔐 Security

- **Sealed Secrets**: All sensitive data is encrypted before storing in Git
- **Environment Isolation**: Separate secrets for each environment
- **GitOps Ready**: Safe to store in public repositories
- **Automatic Decryption**: Secrets are automatically decrypted in the cluster

## 🌐 Environments

- **Development**: `dev` namespace
- **Staging**: Coming soon
- **Production**: Coming soon

## 📚 Documentation

All documentation is contained in this README. The project structure is self-documenting with clear naming conventions.

## 🛠️ Development

### Using Task Runners

#### Make
Make provides a consistent experience for running common tasks:

```bash
# Show available commands
make help

# Setup environment
make setup

# Test Helm chart
make lint
make template

# Apply to cluster
make apply-dev

# Manage secrets
make secret-list
make create-secret NAME=API_KEY VALUE=your-secret-value
make update-secret NAME=MYSQL_PASSWORD VALUE=new-password

# Check status
make status
make logs-ai
```

### Manual Commands
Test Helm chart locally:
```bash
helm lint charts/smartrent/
helm template charts/smartrent/ --values charts/smartrent/environments/dev/values.yaml
```

### Direct Script Usage (Advanced)
For advanced users who prefer direct script access:
```bash
./scripts/setup.sh
./scripts/manage-secrets dev list
```
