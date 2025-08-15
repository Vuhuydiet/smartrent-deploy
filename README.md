# How to deploy

## Dependencies
1. Kubernetes cluster
2. Install Ingress Controller
3. Install Argocd (in argocd namespace)
4. Install Cert-Manager
5 Install Kubernetes Monitoring Stack

## Create Ingress for ArgoCD Server (UI)
```bash
  kubectl apply -f argocd-config/argocd-ingress.yaml
```

## Create applications
```bash
  kubectl apply -f apps/dev-application.yaml
  kubectl apply -f apps/staging-application.yaml