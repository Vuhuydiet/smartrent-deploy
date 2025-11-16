# SmartRent Kubernetes Deployment

## 🚀 Deployment

### 1. Configure Secrets

```bash
# Edit secrets (replace all CHANGE_ME values)
code charts/smartrent/environments/dev/secrets.yaml
```

### 2. Apply Secrets

```bash
kubectl create namespace dev
kubectl apply -f charts/smartrent/environments/dev/secrets.yaml
```

### 3. Deploy

```bash
kubectl apply -f apps/dev-application.yaml
```

### 4. Verify

```bash
kubectl get pods -n dev
kubectl logs -f deployment/backend-server -n dev
```

## 🌐 Endpoints

- Dev: https://dev.smartrent-api.vuhuydiet.xyz
- Production: https://smartrent-api.vuhuydiet.xyz

## 🔄 Update

CI/CD auto-deploys on push to main. ArgoCD syncs within minutes.
