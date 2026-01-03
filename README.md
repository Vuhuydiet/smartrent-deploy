# SmartRent Kubernetes Deployment

This repository contains Kubernetes manifests and Helm charts for deploying the SmartRent application stack using ArgoCD GitOps.

## 📋 Prerequisites

- Kubernetes cluster (1.24+)
- ArgoCD installed
- cert-manager installed (for HTTPS/TLS)
- nginx-ingress-controller installed
- kubectl configured

## 🚀 Deployment

### 1. Setup cert-manager for HTTPS

```bash
# Install cert-manager (if not already installed)
# Update email in config/cert-manager-issuer.yaml
# Then apply ClusterIssuer
kubectl apply -f config/cert-manager-issuer.yaml
```

See [HTTPS_SETUP.md](HTTPS_SETUP.md) for detailed HTTPS configuration.

### 2. Configure Secrets

```bash
# Edit secrets (replace all CHANGE_ME values)
code charts/smartrent/environments/dev/secrets.yaml
```

### 3. Apply Secrets

```bash
kubectl create namespace dev
kubectl apply -f charts/smartrent/environments/dev/secrets.yaml
```

### 4. Deploy via ArgoCD

```bash
# Apply ArgoCD Application
kubectl apply -f apps/dev-application.yaml

# Or sync manually
argocd app sync smartrent-dev
```

### 5. Verify

```bash
# Check ArgoCD application
argocd app get smartrent-dev

# Check pods
kubectl get pods -n dev

# Check certificates
kubectl get certificate -n dev

# Check logs
kubectl logs -f deployment/backend-server -n dev
```

## 🌐 Endpoints

- **Dev Backend**: https://dev.smartrent-api.vuhuydiet.xyz
- **Dev Scraper**: https://scraper.dev.smartrent-api.vuhuydiet.xyz
- **Dev AI**: https://ai.dev.smartrent-api.vuhuydiet.xyz
- **Production**: https://smartrent-api.vuhuydiet.xyz

## 🔄 Update Workflow

This repository uses GitOps with ArgoCD:

1. Make changes to configuration files
2. Commit and push to repository
3. ArgoCD automatically syncs changes (configured with automated sync)
4. Verify deployment in ArgoCD UI or CLI

```bash
# Watch sync progress
argocd app watch smartrent-dev

# Manual sync if needed
argocd app sync smartrent-dev
```

## 📁 Repository Structure

```
smartrent-deploy/
├── apps/                          # ArgoCD Application manifests
│   ├── dev-application.yaml       # Development environment
│   └── prd-application.yaml       # Production environment
├── charts/smartrent/              # Helm chart
│   ├── templates/                 # Kubernetes manifests
│   ├── environments/              # Environment-specific values
│   │   ├── dev/
│   │   └── prd/
│   └── values.yaml                # Default values
├── config/                        # Cluster-wide configurations
│   ├── cert-manager-issuer.yaml   # Let's Encrypt TLS certificates
│   └── argocd-ingress.yaml        # ArgoCD ingress
└── HTTPS_SETUP.md                 # HTTPS configuration guide
```

## 🔒 Security

- ✅ HTTPS/TLS enabled with automatic certificate management
- ✅ Secrets stored in Kubernetes secrets
- ✅ Separate namespaces for dev/production
- ⚠️ Update all `CHANGE_ME` values in secrets files

## 📖 Documentation

- [HTTPS Setup Guide](HTTPS_SETUP.md) - Detailed HTTPS/TLS configuration
- [ArgoCD Applications](apps/) - GitOps application definitions
- [Helm Chart](charts/smartrent/) - Application deployment manifests
