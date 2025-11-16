# Quick HTTPS Setup with ArgoCD

## 🚀 Quick Start (5 minutes)

### Step 1: Update Email in ClusterIssuer
```bash
# Edit the file and replace your-email@example.com
notepad config/cert-manager-issuer.yaml
```

### Step 2: Apply ClusterIssuer
```bash
kubectl apply -f config/cert-manager-issuer.yaml
```

### Step 3: Push Changes (ArgoCD will auto-sync)
```bash
git add .
git commit -m "Enable HTTPS with cert-manager"
git push
```

### Step 4: Verify (wait 2-3 minutes)
```bash
# Check ArgoCD sync
argocd app get smartrent-dev

# Check certificate (should show "Ready")
kubectl get certificate -n dev

# Test HTTPS
curl https://dev.smartrent-api.vuhuydiet.xyz/actuator/health
```

## ✅ What's Configured

- ✅ TLS/HTTPS on all ingress endpoints
- ✅ Automatic SSL certificates from Let's Encrypt
- ✅ HTTP to HTTPS redirect
- ✅ Auto-renewal via cert-manager
- ✅ Updated backend URLs to use HTTPS:
  - VNPay IPN URL
  - Google OAuth redirect URI
  - Client URL

## 📊 Check Status

```bash
# Certificate status
kubectl get certificate -n dev

# Ingress status
kubectl get ingress -n dev

# ArgoCD app status
argocd app get smartrent-dev
```

## 🔧 Troubleshooting

### Certificate pending?
```bash
kubectl describe certificate smartrent-tls-dev -n dev
kubectl get certificaterequest -n dev
```

### DNS not resolving?
```bash
nslookup dev.smartrent-api.vuhuydiet.xyz
```

### ArgoCD not syncing?
```bash
argocd app sync smartrent-dev
```

## 📚 Full Documentation

See [HTTPS_SETUP.md](HTTPS_SETUP.md) for complete documentation.
