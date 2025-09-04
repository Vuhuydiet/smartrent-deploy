# SmartRent Deploy

GitOps deployment configuration for SmartRent AI application using ArgoCD and Sealed Secrets.

## 🏗️ Project Structure

```bash
smartrent-deploy/
├── apps/                           # ArgoCD Applications
│   └── dev-application.yaml       # Development environment app
├── charts/smartrent/               # Helm Chart
│   ├── .helmignore                # Helm ignore file
│   ├── Chart.yaml                 # Helm chart metadata
│   ├── values.yaml                # Default Helm values
│   ├── templates/                  # Kubernetes manifests
│   │   ├── ai.yaml                # AI service deployment
│   │   ├── backend.yaml           # Backend service deployment
│   │   ├── ingress.yaml           # Ingress configuration
│   │   └── scraper.yaml           # Scraper service deployment
│   └── environments/              # Environment-specific configs
│       ├── dev/
│       │   └── values.yaml        # Dev environment values
│       └── prd/
│           └── values.yaml        # Production environment values
├── config/                        # Infrastructure configs
│   └── argocd-ingress.yaml       # ArgoCD ingress
└── diff/                          # Patch files
    ├── diff.patch                 # General patch file
    └── diff_err.patch            # Error patch file
```

## 🚀 Quick Start

### Prerequisites
- Kubernetes cluster
- ArgoCD installed
- Sealed Secrets controller installed

### Setup

1. **Install Prerequisites**:
```bash
  # Install ArgoCD in your cluster
  kubectl create namespace argocd
  kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

  # Apply ArgoCD ingress (optional)
  kubectl apply -f config/argocd-ingress.yaml
```

2. **Deploy the Application**:
```bash
  # Apply the ArgoCD application for development
  kubectl apply -f apps/dev-application.yaml
```

## 🔐 Security

- **Environment Isolation**: Separate configurations for each environment
- **GitOps Ready**: Configuration stored in version control
- **Kubernetes Native**: Uses Kubernetes secrets and config management
- **Environment-specific Values**: Sensitive data managed through Helm values

## 🔑 Secrets Management

### Creating Kubernetes Secrets

#### Method 1: Using kubectl (for development)

```bash
# Create a secret from literal values
kubectl create secret generic app-secrets \
  --from-literal=database-url="postgresql://user:pass@host:5432/db" \
  --from-literal=api-key="your-api-key" \
  --namespace=dev

# Create a secret from files
kubectl create secret generic app-config \
  --from-file=config.json \
  --from-file=credentials.yaml \
  --namespace=dev

# Create a TLS secret
kubectl create secret tls app-tls \
  --cert=path/to/cert.crt \
  --key=path/to/cert.key \
  --namespace=dev
```

#### Method 2: Using YAML manifests

```yaml
# secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
  namespace: dev
type: Opaque
data:
  database-url: <base64-encoded-value>
  api-key: <base64-encoded-value>
```

```bash
# Apply the secret
kubectl apply -f secret.yaml
```

### Creating Sealed Secrets (for production)

Sealed Secrets provide a secure way to store encrypted secrets in Git repositories.

#### Prerequisites

```bash
# Install sealed-secrets controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# Install kubeseal CLI tool
# On Windows with Chocolatey:
choco install kubeseal

# On macOS with Homebrew:
brew install kubeseal

# On Linux:
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/kubeseal-0.24.0-linux-amd64.tar.gz
tar -xvzf kubeseal-0.24.0-linux-amd64.tar.gz
sudo install -m 755 kubeseal /usr/local/bin/kubeseal
```

#### Creating Sealed Secrets

```bash
# Method 1: Create from kubectl and pipe to kubeseal
kubectl create secret generic app-secrets \
  --from-literal=database-url="postgresql://user:pass@host:5432/db" \
  --from-literal=api-key="your-api-key" \
  --dry-run=client -o yaml | \
  kubeseal -o yaml > sealed-secret.yaml

# Method 2: Create from existing secret
kubectl get secret app-secrets -o yaml | kubeseal -o yaml > sealed-secret.yaml

# Method 3: Create directly with kubeseal
echo -n "your-secret-value" | kubeseal --raw --from-file=/dev/stdin --name=secret-name --namespace=dev

# Apply the sealed secret
kubectl apply -f sealed-secret.yaml
```

#### Sealed Secret Example

```yaml
# sealed-secret.yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: app-secrets
  namespace: dev
spec:
  encryptedData:
    database-url: AgBy3i4OJSWK+PiTySYZZA9rO43cGDEQAx...
    api-key: AgBy3i4OJSWK+PiTySYZZA9rO43cGDEQAx...
  template:
    metadata:
      name: app-secrets
      namespace: dev
    type: Opaque
```

### Best Practices

1. **Never commit plain text secrets** to Git repositories
2. **Use sealed secrets for production** environments stored in Git
3. **Use separate secrets per environment** (dev, staging, prod)
4. **Rotate secrets regularly** and update sealed secrets accordingly
5. **Use meaningful secret names** that describe their purpose
6. **Test secret access** in your applications before deployment

### Debugging Secrets

```bash
# List secrets in a namespace
kubectl get secrets -n dev

# Describe a secret (shows metadata, not values)
kubectl describe secret app-secrets -n dev

# Decode secret values (be careful in production!)
kubectl get secret app-secrets -n dev -o jsonpath='{.data.api-key}' | base64 --decode

# Check if sealed secret was successfully unsealed
kubectl get sealedsecrets -n dev
kubectl logs -n kube-system -l name=sealed-secrets-controller
```

## 🌐 Environments

- **Development**: `dev` namespace - Development environment configuration
- **Production**: `prd` namespace - Production environment configuration
- **Staging**: Coming soon

## 📚 Documentation

All documentation is contained in this README. The project structure is self-documenting with clear naming conventions.

## 🛠️ Development

### Helm Operations

Work with the Helm chart directly:

```bash
  # Lint the Helm chart
  helm lint charts/smartrent

  # Template the chart for development
  helm template smartrent charts/smartrent -f charts/smartrent/environments/dev/values.yaml

  # Template the chart for production
  helm template smartrent charts/smartrent -f charts/smartrent/environments/prd/values.yaml

  # Install/upgrade for development
  helm upgrade --install smartrent charts/smartrent -f charts/smartrent/environments/dev/values.yaml -n dev --create-namespace

  # Install/upgrade for production
  helm upgrade --install smartrent charts/smartrent -f charts/smartrent/environments/prd/values.yaml -n prd --create-namespace
```

### ArgoCD Operations

```bash
  # Apply the ArgoCD application
  kubectl apply -f apps/dev-application.yaml

  # Check ArgoCD application status
  kubectl get applications -n argocd

  # Sync the application manually
  argocd app sync smartrent-dev
```
