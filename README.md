# Registration App — EKS / Kubernetes

Full-stack registration app (FastAPI + PostgreSQL + React) migrated from EC2 to Kubernetes with a full DevSecOps pipeline.

## Stack

| Layer | Technology |
|---|---|
| Frontend | React 18 + Nginx |
| Backend | FastAPI (Python 3.9) |
| Database | PostgreSQL 15 |
| Container Build | Podman |
| Orchestration | Kubernetes (kind locally / EKS on AWS) |
| GitOps CD | ArgoCD |
| CI Pipeline | GitHub Actions |
| Code Scanning | SonarQube |
| Image Scanning | Trivy + Snyk |
| DAST Scanning | OWASP ZAP |
| Observability | Prometheus + Loki + Grafana |
| Alerts | Slack |

## Folder Structure

```
registration-app-EKS/
├── backend/                  # FastAPI app
├── frontend/                 # React app
├── k8s/
│   ├── namespace/            # Namespace, Secrets, ConfigMap
│   ├── postgres/             # PostgreSQL Deployment, Service, PVC
│   ├── backend/              # Backend Deployment, Service
│   └── frontend/             # Frontend Deployment, Service
├── argocd/                   # ArgoCD Application manifest
├── helm/                     # Helm charts (coming soon)
├── monitoring/               # Prometheus + Loki + Grafana configs
├── .github/workflows/        # GitHub Actions CI/CD pipeline
├── kind-config.yaml          # Local kind cluster config
└── README.md
```

## Local Setup (kind)

### Prerequisites
- Docker Desktop
- kind
- kubectl
- Helm

### 1. Create kind cluster
```bash
kind create cluster --config kind-config.yaml
```

### 2. Update secrets
Edit `k8s/namespace/secrets.yaml` with your real values (never commit real secrets!)

### 3. Deploy the app
```bash
kubectl apply -f k8s/namespace/
kubectl apply -f k8s/postgres/
kubectl apply -f k8s/backend/
kubectl apply -f k8s/frontend/
```

### 4. Access the app
```
Frontend:  http://localhost:30080
Backend:   kubectl port-forward svc/backend-service 8000:8000 -n registration-app
```

### 5. Install ArgoCD
```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl apply -f argocd/application.yaml

# Access ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Open https://localhost:8080
```

## GitHub Actions Secrets Required

| Secret | Description |
|---|---|
| `DOCKER_USERNAME` | Docker Hub username |
| `DOCKER_PASSWORD` | Docker Hub password |
| `SONAR_TOKEN` | SonarQube token |
| `SONAR_HOST_URL` | SonarQube server URL |
| `SNYK_TOKEN` | Snyk API token |
| `SLACK_WEBHOOK_URL` | Slack webhook for notifications |
| `APP_URL` | Deployed app URL for OWASP ZAP |
| `REACT_APP_API_URL` | Backend API URL for frontend build |

## Architecture

```
GitHub Push
    ↓
GitHub Actions (CI)
SonarQube → Podman Build → Trivy + Snyk → Push to Docker Hub
    ↓
ArgoCD detects new image tag in manifests (CD)
    ↓
Deploys to Kubernetes cluster (kind / EKS)
    ↓
OWASP ZAP scans running app
    ↓
Prometheus + Loki + Grafana (observability)
    ↓
Slack notifications
```