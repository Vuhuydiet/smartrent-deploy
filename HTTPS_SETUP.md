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

### 3. Deploy with HTTPS

The ingress configuration is now set up to automatically request SSL certificates from Let's Encrypt.

```bash
# Deploy using Helm
helm upgrade --install smartrent ./charts/smartrent \
  -f charts/smartrent/environments/dev/values.yaml \
  -f charts/smartrent/environments/dev/secrets.yaml \
  --namespace smartrent \
  --create-namespace

# Check certificate status
kubectl get certificate -n smartrent
kubectl describe certificate smartrent-tls-dev -n smartrent
```

### 4. Verify HTTPS

Once the certificate is issued (can take a few minutes):

```bash
# Check certificate
kubectl get certificate -n smartrent

# Check ingress
kubectl get ingress -n smartrent

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
# Check certificate status
kubectl describe certificate smartrent-tls-dev -n smartrent

# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager

# Check certificate request
kubectl get certificaterequest -n smartrent
kubectl describe certificaterequest -n smartrent
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

## Next Steps

1. Update your email in `config/cert-manager-issuer.yaml`
2. Apply the ClusterIssuer: `kubectl apply -f config/cert-manager-issuer.yaml`
3. Deploy or upgrade your Helm chart
4. Verify certificates are issued successfully
5. Test all HTTPS endpoints
6. Update production environment similarly
