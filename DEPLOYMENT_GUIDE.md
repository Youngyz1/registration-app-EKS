# Registration App - EKS Deployment Guide

## Quick Start After Infrastructure Shutdown

### 1. Reprovision Infrastructure
```bash
cd terraform
terraform apply -auto-approve
```

### 2. Get Outputs
```bash
terraform output -json
# Save the ALB_DNS and update GitHub secret: REACT_APP_API_URL
```

### 3. Update GitHub Secret
- Go to: https://github.com/Youngyz1/registration-app-EKS/settings/secrets/actions
- Update `REACT_APP_API_URL` with new ALB DNS: `http://<ALB_DNS>/api`

### 4. Deploy Application
```bash
# The CI/CD pipeline will automatically:
# - Build Docker images
# - Scan for vulnerabilities  
# - Deploy to EKS via Helm
# - Initialize database tables

git add .
git commit -m "chore: redeploy after infrastructure refresh"
git push origin main
```

### 5. Verify Deployment
```bash
# Wait for pipeline to complete (~5-10 minutes)
# Then test the API

# Register
curl -X POST http://<ALB_DNS>/api/register \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","email":"test@example.com","password":"password123"}'

# Login
curl -X POST http://<ALB_DNS>/api/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=testuser&password=password123"

# Test protected endpoint
curl http://<ALB_DNS>/api/users/me \
  -H "Authorization: Bearer <JWT_TOKEN>"
```

## Key Files

- `backend/init_db.py` - Database initialization (creates tables on startup)
- `backend/database.py` - Database connection and session management
- `backend/main.py` - FastAPI application with all endpoints
- `backend/models.py` - SQLAlchemy User model
- `.github/workflows/ci-cd.yml` - CI/CD pipeline configuration
- `helm/registration-app/values.yaml` - Helm chart values for deployment
- `terraform/` - Infrastructure as Code (EKS, RDS, ALB, etc.)

## Troubleshooting

### Database Tables Not Created
The app now automatically creates tables on startup via `init_db.py`. If issues persist:
```bash
kubectl exec -it pod/backend-xxxxx -n registration-app -- \
  python -c "from init_db import init_db; init_db()"
```

### Login Failing
Check backend logs:
```bash
kubectl logs -n registration-app deployment/backend -f | grep LOGIN
```

### API URL Issues
Verify GitHub secret matches new ALB DNS:
```bash
echo "Expected: http://<new-alb-dns>/api"
```

## Environment Variables Required

**GitHub Secrets:**
- `DOCKER_USERNAME` - Docker Hub username
- `DOCKER_PASSWORD` - Docker Hub password
- `REACT_APP_API_URL` - Backend API URL (updated after each infrastructure change)
- `SONAR_TOKEN` - SonarCloud token

**Kubernetes Secrets (in values.yaml):**
- `DB_USER` - Database username
- `DB_PASSWORD` - Database password
- `DB_HOST` - RDS endpoint
- `DB_PORT` - Database port (5432)
- `DB_NAME` - Database name
- `JWT_SECRET_KEY` - Secret key for JWT tokens

## Infrastructure Costs (AWS)

- EKS Cluster: ~$0.10/hour
- RDS PostgreSQL: ~$0.15/hour (multi-AZ)
- ALB: ~$0.0225/hour
- NAT Gateway: ~$0.045/hour
- **Total: ~$150-200/month**

To save costs, destroy when not in use:
```bash
terraform destroy -auto-approve
```
