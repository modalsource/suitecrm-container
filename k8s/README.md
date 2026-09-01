# SuiteCRM on OVH Managed Kubernetes

Plain-YAML manifests for **OVHcloud Managed Kubernetes Service (MKS)**.
The stack is split into two independent axes:

1. **Database** — `database/mariadb` (example) vs **Percona/external** (bring your own, not included)
2. **Ingress** — **NGINX** vs **Traefik** (differentiated manifests)

```
k8s/
├── namespace.yaml
├── kustomization.yaml                 # legacy alias -> NGINX full-stack (see overlays/)
├── app/                              # SuiteCRM base (without Ingress, agnostic)
│   ├── kustomization.yaml            # pvc + secret + suitecrm + cronjob
│   ├── pvc.yaml
│   ├── secret.yaml                   # db-password + admin password
│   ├── suitecrm.yaml                 # configurable DB host
│   ├── cronjob.yaml
│   ├── ingress-nginx.yaml            # IngressClass nginx + nginx annotations
│   └── ingress-traefik.yaml          # IngressClass traefik + Middleware buffering
├── database/
│   └── mariadb/                      # example MariaDB 11.4
│       ├── pvc.yaml, secret.yaml, mariadb.yaml
└── overlays/                         # EXPLICIT ingress + stack choice
    ├── nginx/kustomization.yaml      # app + ingress-nginx + mariadb
    ├── traefik/kustomization.yaml    # app + ingress-traefik + mariadb
    ├── app-nginx/kustomization.yaml  # app + ingress-nginx (external DB)
    └── app-traefik/kustomization.yaml# app + ingress-traefik (external DB)
```

## Ingress Choice: NGINX vs Traefik

On **OVH MKS** both create an **Octavia Load Balancer** in front of the controller, but installation and annotations differ.

| | **NGINX** (`ingress-nginx.yaml`) | **Traefik** (`ingress-traefik.yaml`) |
|---|---|---|
| **IngressClass** | `nginx` | `traefik` |
| **Install** | `helm install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx --set controller.service.type=LoadBalancer` | `helm install traefik traefik/traefik -n traefik --set service.type=LoadBalancer` or use Traefik already present on MKS (`kubectl get ingressclass`) |
| **Body limit 100M** | `nginx.ingress.kubernetes.io/proxy-body-size: "100m"` | Middleware `buffering.maxRequestBodyBytes: 104857600` (included) — Traefik does NOT limit by default |
| **Timeout 600s** | `proxy-read/send-timeout: "600"` | Handled via entryPoints/Middleware (no annotation needed) |
| **TLS** | `cert-manager.io/cluster-issuer: letsencrypt-prod` + `spec.tls` | Same with cert-manager **or** `traefik.ingress.kubernetes.io/router.tls.certresolver: letsencrypt` (Traefik native) |
| **Redirect HTTP→HTTPS** | `nginx.ingress.kubernetes.io/ssl-redirect: "true"` | Middleware `redirectScheme` (`suitecrm-redirect-https`) |
| **File** | `k8s/app/ingress-nginx.yaml:1` | `k8s/app/ingress-traefik.yaml:1` (+ 2 Middlewares) |

**Which one to choose on OVH?**
- **NGINX** recommended if starting from scratch — more OVH examples, best cert-manager compatibility.
- **Traefik** if your OVH cluster already exposes it by default or you use other Traefik features (Middleware, ForwardAuth, etc.).

Both expose the same `host: suitecrm.example.com` to `Service/suitecrm:80` and require a DNS A record pointing to the OVH LB external IP.

## Database Choice

### A) MariaDB in-cluster (example)

```bash
vi k8s/app/secret.yaml              # db-password
vi k8s/database/mariadb/secret.yaml # mysql-password (= db-password) + mysql-root-password
# Full-stack NGINX:
kubectl apply -k k8s/overlays/nginx
# Full-stack Traefik:
kubectl apply -k k8s/overlays/traefik
```

### B) Percona / OVH Cloud DB / external

Do not deploy `k8s/database/mariadb`. Bring your own DB and point `SUITECRM_INSTALL_DB_HOST`:

```bash
vi k8s/app/secret.yaml   # db-password
vi k8s/app/suitecrm.yaml # SUITECRM_INSTALL_DB_HOST/PORT/NAME/USER
# App only + Ingress:
kubectl apply -k k8s/overlays/app-nginx   # or app-traefik
```

## OVH Prerequisites

1. **MKS Cluster** (≥ 1.29) + kubeconfig + `kubectl get storageclasses` (`csi-cinder-high-speed` recommended).
2. **Image** `suitecrm:7.15.2-r0` (Bitnami-style `X.Y.Z-rN` → tag GHCR `7.15.2-r0`, `7.15.2`, `7.15`, `7` senza `latest`) built and pushed to OVH Harbor / GHCR (`k8s/app/suitecrm.yaml:53` + `cronjob.yaml:26`).
3. **Ingress controller** — install **one** of the two:

**NGINX:**
```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.service.type=LoadBalancer
kubectl get svc -n ingress-nginx ingress-nginx-controller --watch
```

**Traefik:**
```bash
helm repo add traefik https://traefik.github.io/charts
helm repo update
helm upgrade --install traefik traefik/traefik \
  --namespace traefik --create-namespace \
  --set service.type=LoadBalancer
kubectl get svc -n traefik traefik --watch
# check: kubectl get ingressclass
```

4. **(Optional) cert-manager** for Let's Encrypt TLS (works with both):
```bash
helm repo add jetstack https://charts.jetstack.io
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace --set installCRDs=true
# uncomment ClusterIssuer in k8s/app/ingress-nginx.yaml:54 or ingress-traefik.yaml:58
# and annotation cert-manager.io/cluster-issuer on the Ingress
```

## Installation

### 1. Configure secrets and domain

```bash
vi k8s/app/secret.yaml              # db-password, suitecrm-admin-password
vi k8s/app/ingress-nginx.yaml       # host
# or
vi k8s/app/ingress-traefik.yaml     # host
vi k8s/app/suitecrm.yaml            # SUITECRM_INSTALL_SITE_URL = https://suitecrm.example.com
```

### 2. Deploy

```bash
# App + DB + NGINX:
kubectl apply -k k8s/overlays/nginx

# App + DB + Traefik:
kubectl apply -k k8s/overlays/traefik

# App only (external DB) + NGINX:
kubectl apply -k k8s/overlays/app-nginx

# App only (external DB) + Traefik:
kubectl apply -k k8s/overlays/app-traefik

# Legacy (equivalent to overlays/nginx):
kubectl apply -k k8s/
```

Direct apply without Kustomize (e.g. Ingress only):
```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/app/pvc.yaml -f k8s/app/secret.yaml -f k8s/app/suitecrm.yaml -f k8s/app/cronjob.yaml
kubectl apply -f k8s/app/ingress-nginx.yaml   # or ingress-traefik.yaml
```

Wait for first boot (~30s extraction + 1-2 min silent install):
```bash
kubectl get pods -n suitecrm -w
kubectl logs -f -n suitecrm deployment/suitecrm
```

### 3. Verify

```bash
kubectl get ingress -n suitecrm
# NGINX: kubectl get svc -n ingress-nginx ingress-nginx-controller
# Traefik: kubectl get svc -n traefik traefik
curl -k https://suitecrm.example.com
# login: admin / <suitecrm-admin-password>
```

## OVH Notes

- **PVC RWO** (`csi-cinder-high-speed`) → `replicas: 1`, `strategy: Recreate`. For HA >1 you need RWX (OVH NAS-HA / Manila).
- **Legacy `k8s/kustomization.yaml`** keeps `ingress-nginx` for backward compatibility; for Traefik use `k8s/overlays/traefik` explicitly.
- **Traefik CRD** `traefik.io/v1alpha1` requires Traefik ≥ v3; on v2 use `traefik.containo.us/v1alpha1` (change `apiVersion` in the Middleware).

## Troubleshooting

- `Pending PVC`: `kubectl describe pvc -n suitecrm` — StorageClass / Cinder quota.
- `Ingress 404`: check `ingressClassName` (`nginx` vs `traefik`) and controller `EXTERNAL-IP`.
- `413 Body Too Large` (NGINX): check `proxy-body-size` on Ingress; (Traefik): check Middleware `suitecrm-buffer`.
- `DB not reachable`: `kubectl exec -n suitecrm deploy/suitecrm -- nc -zv $SUITECRM_INSTALL_DB_HOST $SUITECRM_INSTALL_DB_PORT`.
