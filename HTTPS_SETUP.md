# HTTPS Configuration for SmartRent Backend

This document describes the HTTPS/TLS configuration for the SmartRent backend services.

## Prerequisites

1. **cert-manager** installed in your Kubernetes cluster
2. **nginx-ingress-controller** installed
3. Valid DNS records pointing to your ingress controller's external IP

## Installation Steps

### 1. Install cert-manager (if not already installed)

```bash
# Add the Jetstack Helm repository
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Verify installation
kubectl get pods --namespace cert-manager
```

### 2. Configure Let's Encrypt ClusterIssuer

Edit `config/cert-manager-issuer.yaml` and replace `your-email@example.com` with your actual email address.

```bash
# Apply the ClusterIssuer configuration
kubectl apply -f config/cert-manager-issuer.yaml

# Verify ClusterIssuer is ready
kubectl get clusterissuer
```

### 3. Deploy with HTTPS (ArgoCD GitOps)

The ingress configuration is now set up to automatically request SSL certificates from Let's Encrypt.

```bash
# Commit and push your changes to the repository
git add .
git commit -m "Configure HTTPS with cert-manager"
git push

# ArgoCD will automatically sync the changes
# Or manually sync via ArgoCD UI or CLI:
argocd app sync smartrent-dev

# Check certificate status (namespace is 'dev' for dev environment)
kubectl get certificate -n dev
kubectl describe certificate smartrent-tls-dev -n dev
```

**Note:** ArgoCD is configured with automated sync, so changes will be applied automatically within a few minutes after pushing to the repository.

### 4. Verify HTTPS

Once the certificate is issued (can take a few minutes):

```bash
# Check ArgoCD sync status
kubectl get applications -n argocd
argocd app get smartrent-dev

# Check certificate
kubectl get certificate -n dev

# Check ingress
kubectl get ingress -n dev

# Test HTTPS endpoints
curl https://dev.smartrent-api.vuhuydiet.xyz/actuator/health
curl https://scraper.dev.smartrent-api.vuhuydiet.xyz/health
curl https://ai.dev.smartrent-api.vuhuydiet.xyz/health
```

## Configuration Details

### Ingress Annotations

The following annotations are configured in `charts/smartrent/templates/ingress.yaml`:

- `cert-manager.io/cluster-issuer: letsencrypt-prod` - Uses Let's Encrypt production issuer
- `nginx.ingress.kubernetes.io/ssl-redirect: "true"` - Redirects HTTP to HTTPS
- `nginx.ingress.kubernetes.io/force-ssl-redirect: "true"` - Forces SSL redirect

### TLS Configuration

The ingress is configured with TLS for the following domains:

**Development:**
- dev.smartrent-api.vuhuydiet.xyz (Backend)
- scraper.dev.smartrent-api.vuhuydiet.xyz (Scraper)
- ai.dev.smartrent-api.vuhuydiet.xyz (AI Service)

**Production:**
- smartrent-api.vuhuydiet.xyz (Backend)
- scraper.smartrent-api.vuhuydiet.xyz (Scraper)

### Environment Variables Updated

The following URLs have been updated to use HTTPS:

- `VNPAY_IPN_URL`: Now uses HTTPS backend URL
- `GOOGLE_AUTH_CLIENT_REDIRECT_URI`: Updated to HTTPS frontend URL
- `CLIENT_URL`: Updated to HTTPS frontend URL

## Troubleshooting

### Certificate not issuing

```bash
# Check ArgoCD application status first
argocd app get smartrent-dev

# Check certificate status
kubectl describe certificate smartrent-tls-dev -n dev

# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager

# Check certificate request
kubectl get certificaterequest -n dev
kubectl describe certificaterequest -n dev
```

### Let's Encrypt Rate Limits

If testing, use the staging issuer first to avoid rate limits:

```yaml
cert-manager.io/cluster-issuer: letsencrypt-staging
```

Once verified, switch to production:

```yaml
cert-manager.io/cluster-issuer: letsencrypt-prod
```

### DNS Issues

Ensure your DNS records are properly configured:

```bash
# Check DNS resolution
nslookup dev.smartrent-api.vuhuydiet.xyz
nslookup scraper.dev.smartrent-api.vuhuydiet.xyz
nslookup ai.dev.smartrent-api.vuhuydiet.xyz
```

## Security Recommendations

1. ✅ All traffic is forced to HTTPS
2. ✅ Automatic certificate renewal via cert-manager
3. ✅ Production-grade SSL certificates from Let's Encrypt
4. 🔄 Consider adding HSTS headers for enhanced security
5. 🔄 Consider implementing rate limiting at ingress level

## ArgoCD GitOps Workflow

Since you're using ArgoCD, the deployment process is simplified:

1. **Make changes** to your configuration files in this repository
2. **Commit and push** to GitHub
3. **ArgoCD automatically syncs** (configured with `automated: selfHeal: true`)
4. **Verify** the deployment in ArgoCD UI or CLI

```bash
# Watch ArgoCD sync in real-time
argocd app watch smartrent-dev

# Manual sync if needed
argocd app sync smartrent-dev

# Check sync status
argocd app get smartrent-dev
```

## Next Steps

1. ✅ Update your email in `config/cert-manager-issuer.yaml`
2. ✅ Apply the ClusterIssuer: `kubectl apply -f config/cert-manager-issuer.yaml`
3. ✅ Commit and push changes: `git add . && git commit -m "Configure HTTPS" && git push`
4. ⏳ Wait for ArgoCD to sync (or manually sync)
5. ✅ Verify certificates are issued: `kubectl get certificate -n dev`
6. ✅ Test all HTTPS endpoints
7. 🔄 Update production environment similarly in `environments/prd/values.yaml`
