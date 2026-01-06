# Domain Migration and HTTPS Fix Guide

## Overview

When changing domains for a Kubernetes deployment using nginx-ingress and cert-manager, you may encounter HTTPS connectivity issues. This document summarizes common errors and their solutions.

## Root Causes

1. **Load Balancer IP Changed** - When recreating the Load Balancer, a new IP is assigned
2. **DNS Not Updated** - DNS records still point to the old IP
3. **cert-manager DNS Cache** - cert-manager has cached the old IP in memory
4. **PROXY Protocol Conflict** - Mismatch between nginx ingress controller and DigitalOcean Load Balancer PROXY protocol configuration

## Steps to Fix When Changing Domain

### 1. Get New Load Balancer IP

```bash
kubectl get svc ingress-nginx-controller -n ingress-nginx
```

Output will show EXTERNAL-IP, e.g., `144.126.242.134`

### 2. Update DNS Records

Access your DNS provider (DigitalOcean, Cloudflare, etc.) and update all A records with the new IP:

- `dev.api.smartrent.io.vn` → new IP
- `api.smartrent.io.vn` → new IP
- `scraper.dev.api.smartrent.io.vn` → new IP
- `scraper.api.smartrent.io.vn` → new IP
- `ai.dev.api.smartrent.io.vn` → new IP
- `argocd.smartrent.io.vn` → new IP

**Note:** DNS propagation takes 1-5 minutes

### 3. Restart cert-manager to Clear DNS Cache

```bash
kubectl rollout restart deployment cert-manager -n cert-manager
```

Verify cert-manager has restarted:

```bash
kubectl get pods -n cert-manager
```

### 4. Delete Old Certificates to Trigger Renewal

```bash
# List all certificates
kubectl get certificate -A

# List certificate requests
kubectl get certificaterequest -n dev

# Delete old certificate request
kubectl delete certificaterequest smartrent-tls-dev-<number> -n dev

# Delete old secret to trigger renewal
kubectl delete secret smartrent-tls-dev -n dev
```

cert-manager will automatically create new certificate requests and challenges.

### 5. Fix PROXY Protocol Error (If Encountered)

**Symptoms:**
- HTTP returns "Empty reply from server" (curl error 52)
- nginx logs show "broken header" errors
- Certificate challenges stuck with "EOF" error

**Fix:**

```bash
# Disable PROXY protocol on Load Balancer
kubectl annotate service ingress-nginx-controller -n ingress-nginx \
  "service.beta.kubernetes.io/do-loadbalancer-enable-proxy-protocol=false" --overwrite

# Disable PROXY protocol in nginx config
kubectl patch configmap ingress-nginx-controller -n ingress-nginx \
  --type merge -p '{"data":{"use-proxy-protocol":"false"}}'

# Restart nginx ingress controller
kubectl rollout restart deployment ingress-nginx-controller -n ingress-nginx
```

Verify nginx controller has restarted:

```bash
kubectl get pods -n ingress-nginx
```

### 6. Verify and Test

Wait 1-2 minutes after restart, then test:

```bash
# Test HTTP (should redirect to HTTPS)
curl -I http://dev.api.smartrent.io.vn/actuator/health

# Test HTTPS (should return 200, 401, or valid response)
curl -I https://dev.api.smartrent.io.vn/actuator/health

# Check certificate status
kubectl get certificate -n dev

# Check challenges (should be empty if successful)
kubectl get challenges -n dev
```

## Common Errors

### 1. Connection Timeout

```
curl: (28) Failed to connect to domain port 443 after 21055 ms
```

**Cause:**
- DNS not pointing to new Load Balancer IP
- Load Balancer not ready
- Firewall blocking ports 80/443

**Fix:**
- Verify DNS propagation: `nslookup dev.api.smartrent.io.vn`
- Check Load Balancer IP: `kubectl get svc -n ingress-nginx`
- Wait a few more minutes for Load Balancer to be ready

### 2. Empty Reply from Server (EOF)

```
curl: (52) Empty reply from server
```

**Cause:** PROXY protocol conflict

**Fix:** Follow step 5 above (Disable PROXY protocol)

### 3. Certificate Challenges Stuck Pending

```bash
kubectl get challenges -n dev
NAME                         STATE     DOMAIN                    AGE
smartrent-tls-dev-xxx        pending   dev.api.smartrent.io.vn   30m
```

**Cause:**
- cert-manager cannot reach HTTP-01 challenge endpoint
- DNS not propagated
- PROXY protocol conflict

**Fix:**
1. Verify DNS resolves to correct IP
2. Test HTTP connectivity: `curl http://dev.api.smartrent.io.vn/.well-known/acme-challenge/test`
3. Check challenge logs:
   ```bash
   kubectl describe challenge <challenge-name> -n dev
   ```
4. If you see "broken header" or "EOF" errors, fix PROXY protocol (step 5)

### 4. Broken Header Error in nginx Logs

```bash
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller --tail=50
```

If you see:
```
[error] broken header: "GET /.well-known/acme-challenge/..." while reading PROXY protocol
```

**Fix:** Disable PROXY protocol (step 5)

## Domain Migration Checklist

- [ ] Update all domain references in code:
  - [ ] `charts/smartrent/environments/dev/values.yaml` - host
  - [ ] `charts/smartrent/environments/prd/values.yaml` - host
  - [ ] Environment variables (VNPAY_IPN_URL, CLIENT_URL, etc.)
  - [ ] `config/argocd-ingress.yaml` - host

- [ ] Commit and push changes to git

- [ ] Get new Load Balancer IP (step 1)

- [ ] Update all DNS A records (step 2)

- [ ] Wait for DNS propagation (1-5 minutes)

- [ ] Restart cert-manager (step 3)

- [ ] Delete old certificates (step 4)

- [ ] If encountering "broken header"/"EOF" errors, fix PROXY protocol (step 5)

- [ ] Verify HTTP and HTTPS working (step 6)

- [ ] Check certificates status = Ready

## Important Notes

1. **DigitalOcean Kubernetes**: Should **disable PROXY protocol** to avoid conflicts with cert-manager self-checks from inside the cluster

2. **DNS Propagation**: Always wait a few minutes after updating DNS records

3. **Certificate Rate Limit**: Let's Encrypt has rate limits (50 certs/domain/week), be careful when testing

4. **Namespace**: Remember to specify the correct namespace when running kubectl commands (`-n dev`, `-n argocd`, etc.)

## Useful Commands

```bash
# List all certificates
kubectl get certificate -A

# Describe certificate details
kubectl describe certificate smartrent-tls-dev -n dev

# List challenges
kubectl get challenges -n dev

# View cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager

# View nginx ingress logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller --tail=100

# List services and external IPs
kubectl get svc -A

# Force delete certificate to recreate
kubectl delete certificate smartrent-tls-dev -n dev
kubectl delete secret smartrent-tls-dev -n dev
```

## References

- [cert-manager Documentation](https://cert-manager.io/docs/)
- [nginx Ingress Controller](https://kubernetes.github.io/ingress-nginx/)
- [DigitalOcean Kubernetes LoadBalancer](https://docs.digitalocean.com/products/kubernetes/how-to/configure-load-balancers/)
- [Let's Encrypt Rate Limits](https://letsencrypt.org/docs/rate-limits/)
