@"
# Registration App EKS - Deployment Guide

**Last Updated:** March 9, 2026
**Kubernetes:** 1.31 | **Istio:** service mesh | **ALB:** internet-facing HTTP

---

## Prerequisites
``````powershell
# Verify tools installed
aws --version
kubectl version --client
helm version
terraform version

# Add Helm repos (first time only)
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo add eks https://aws.github.io/eks-charts
helm repo add external-secrets https://charts.external-secrets.io
helm repo add argo https://argoproj.github.io/argo-helm
helm repo add sonarqube https://SonarSource.github.io/helm-chart-sonarqube
helm repo update
``````

---

## GITHUB SECRETS (REQUIRED BEFORE FIRST DEPLOY)

Go to GitHub repo -> Settings -> Secrets and variables -> Actions and ensure these are set:

| Secret | Description |
|--------|-------------|
| ``AWS_ROLE_ARN`` | ``arn:aws:iam::958421185668:role/github-actions-role`` |
| ``DOCKER_USERNAME`` | Docker Hub username |
| ``DOCKER_PASSWORD`` | Docker Hub password |
| ``SONAR_TOKEN`` | SonarQube project token (generated in SonarQube UI) |
| ``SONAR_HOST_URL`` | SonarQube ALB URL e.g. ``http://<sonarqube-alb-dns>`` |
| ``SLACK_WEBHOOK_URL`` | Slack webhook URL |
| ``REACT_APP_API_URL`` | ALB URL e.g. ``http://<alb-dns>`` - update after first deploy |

Note: ``REACT_APP_API_URL`` is baked into the frontend image at build time.
After a fresh deploy you must update this secret with the new ALB URL and trigger
a rebuild for the frontend to call the correct API endpoint.

---

## FULL DEPLOY (Fresh Infrastructure)

### Step 1 - Provision Infrastructure
``````powershell
cd terraform
terraform init
terraform apply -auto-approve
cd ..
``````

---

### Step 2 - Update kubeconfig
``````powershell
aws eks update-kubeconfig --region us-east-1 --name registration-app-eks
kubectl get nodes
# Both nodes should show: STATUS Ready
``````

---

### Step 3 - Fix ALB IAM Policy (REQUIRED EVERY TERRAFORM APPLY)

Terraform always creates the policy at v1. Must manually promote to default:
``````powershell
``$POLICY_ARN = "arn:aws:iam::958421185668:policy/AWSLoadBalancerControllerIAMPolicy"
aws iam create-policy-version ``
  --policy-arn ``$POLICY_ARN ``
  --policy-document file://terraform/alb-iam-policy.json ``
  --set-as-default
``````

Why: ALB Controller v3.x requires DescribeListenerAttributes and SetRulePriorities
(both included in terraform/alb-iam-policy.json).
Without this, ingress gets no ADDRESS and backend ingress fails with 403.

---

### Step 4 - Install Istio
``````powershell
helm install istio-base istio/base -n istio-system --create-namespace --wait
helm install istiod istio/istiod -n istio-system --wait
``````

---

### Step 5 - Install ALB Controller
``````powershell
``$VPC_ID = terraform -chdir=terraform output -raw vpc_id

helm install aws-load-balancer-controller eks/aws-load-balancer-controller ``
  -n kube-system ``
  --set clusterName=registration-app-eks ``
  --set serviceAccount.create=true ``
  --set "serviceAccount.annotations.eks\.amazonaws\.com/role-arn=arn:aws:iam::958421185668:role/registration-app-eks-alb-controller-role" ``
  --set region=us-east-1 ``
  --set vpcId=``$VPC_ID

Start-Sleep -Seconds 60
kubectl get pods -n kube-system | Select-String "aws-load-balancer"
# Should show: 2 pods, 1/1 Running
``````

---

### Step 6 - Install External Secrets Operator
``````powershell
helm install external-secrets external-secrets/external-secrets ``
  -n external-secrets ``
  --create-namespace ``
  --wait
``````

---

### Step 7 - Install ArgoCD
``````powershell
helm install argocd argo/argo-cd ``
  -n argocd --create-namespace --wait ``
  --set server.service.type=LoadBalancer

# Wait for pods
Start-Sleep -Seconds 60
kubectl get pods -n argocd
# All pods should be Running 1/1
``````

---

### Step 8 - Expose ArgoCD via ALB and disable TLS
``````powershell
# Disable HTTPS redirect via configmap (ArgoCD v3.x method)
'{"data":{"server.insecure":"true"}}' | Out-File -FilePath patch-argocd-cm.json -Encoding ascii
kubectl patch configmap argocd-cmd-params-cm -n argocd --patch-file patch-argocd-cm.json

# Patch argocd-server service to ClusterIP
'{"spec":{"type":"ClusterIP"}}' | Out-File -FilePath patch-argocd-svc.json -Encoding ascii
kubectl patch svc argocd-server -n argocd --patch-file patch-argocd-svc.json

# Create ALB ingress
@"
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-ingress
  namespace: argocd
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80}]'
spec:
  ingressClassName: alb
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              number: 80
"@ | Out-File -FilePath argocd-ingress.yaml -Encoding ascii

kubectl apply -f argocd-ingress.yaml
kubectl rollout restart deployment argocd-server -n argocd

Start-Sleep -Seconds 60
kubectl get ingress -n argocd
# Should show ADDRESS within 2 minutes

# Get ArgoCD URL and admin password
``$ARGOCD_URL = "http://``$(kubectl get ingress argocd-ingress -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
``$ARGOCD_PASS = kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String(``$_)) }
echo "ArgoCD URL: ``$ARGOCD_URL"
echo "ArgoCD Password: ``$ARGOCD_PASS"
``````

Open the URL in your browser and login with ``admin`` / ``<password above>``.
Change the password immediately after first login.

---

### Step 9 - Install SonarQube
``````powershell
helm install sonarqube sonarqube/sonarqube ``
  -n sonarqube --create-namespace ``
  --set service.type=ClusterIP ``
  --set persistence.enabled=true ``
  --set persistence.size=10Gi ``
  --set persistence.storageClass=gp2

Start-Sleep -Seconds 120
kubectl get pods -n sonarqube
# sonarqube-sonarqube-0 should be Running 1/1
``````

---

### Step 10 - Expose SonarQube via ALB
``````powershell
@"
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: sonarqube-ingress
  namespace: sonarqube
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80}]'
spec:
  ingressClassName: alb
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: sonarqube-sonarqube
            port:
              number: 9000
"@ | Out-File -FilePath sonarqube-ingress.yaml -Encoding ascii

kubectl apply -f sonarqube-ingress.yaml
Start-Sleep -Seconds 60

``$SQ_URL = "http://``$(kubectl get ingress sonarqube-ingress -n sonarqube -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
echo "SonarQube URL: ``$SQ_URL"
``````

Open the URL in browser. Login with ``admin`` / ``admin`` - you will be prompted to change password.

---

### Step 11 - Configure SonarQube Project and Token
1. Login to SonarQube
2. Click **Projects** -> **Create Project** -> **Local project**
3. Set project key: ``registration-app``
4. Click **Set up** -> **Locally** -> **Generate token**
5. Copy the token and add to GitHub secrets as ``SONAR_TOKEN``
6. Add SonarQube ALB URL to GitHub secrets as ``SONAR_HOST_URL``

---

### Step 12 - Deploy Application
``````powershell
helm install registration-app helm/registration-app/ ``
  -f helm/registration-app/values.yaml ``
  -n registration-app --create-namespace
``````

This will automatically create:
- Namespace: registration-app
- ServiceAccount: registration-app-sa
- All deployments, services, ingresses, HPA, PDB
- ExternalSecret + SecretStore (syncs secrets from AWS Secrets Manager)

No manual kubectl secret or serviceaccount creation needed.

---

### Step 13 - Apply ArgoCD Application
``````powershell
kubectl apply -f argocd/registration-app.yaml
Start-Sleep -Seconds 10
kubectl get application -n argocd
# Should show: SYNC STATUS=Synced, HEALTH STATUS=Healthy
``````

From this point ArgoCD will automatically sync any changes pushed to main branch.

---

### Step 14 - Label Namespace for Istio
``````powershell
# MUST come AFTER helm install (which creates the namespace)
kubectl label namespace registration-app istio-injection=enabled --overwrite
kubectl rollout restart deployment backend frontend -n registration-app
``````

---

### Step 15 - Verify Pods and Ingress
``````powershell
Start-Sleep -Seconds 120
kubectl get pods -n registration-app
# All 6 pods: READY 2/2 (app + Istio sidecar), STATUS Running

kubectl get ingress -n registration-app
# Both ingresses should show ADDRESS (ALB DNS) within 2-3 minutes
``````

---

### Step 16 - Get Public URL and Update REACT_APP_API_URL
``````powershell
Start-Sleep -Seconds 90
``$ALB_URL = "http://``$(kubectl get ingress registration-app-ingress-frontend -n registration-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
echo "ALB URL: ``$ALB_URL"

curl "``$ALB_URL/api/health" -UseBasicParsing   # Expected: {"status":"healthy"}
curl ``$ALB_URL -UseBasicParsing                # Expected: 200 HTML
``````

IMPORTANT: After getting the ALB URL, update the ``REACT_APP_API_URL`` GitHub secret
with the new ALB URL, then trigger a rebuild so the frontend uses the correct API:
``````powershell
git commit --allow-empty -m "ci: trigger rebuild with updated REACT_APP_API_URL"
git push
``````
## MONITORING SETUP (Prometheus, Grafana, Loki)

### Step 1 - Add Helm Repos
```powershell
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```

---

### Step 2 - Install kube-prometheus-stack (Prometheus + Grafana + Alertmanager)
```powershell
helm install prometheus prometheus-community/kube-prometheus-stack `
  -n monitoring --create-namespace `
  --set grafana.adminPassword=admin123 `
  --set grafana.service.type=ClusterIP `
  --set prometheus.prometheusSpec.service.type=ClusterIP `
  --set alertmanager.alertmanagerSpec.service.type=ClusterIP

Start-Sleep -Seconds 120
kubectl get pods -n monitoring
# All pods should be Running
```

---

### Step 3 - Install Loki Stack (Loki + Promtail)
```powershell
helm install loki grafana/loki-stack `
  -n monitoring `
  --set loki.persistence.enabled=true `
  --set loki.persistence.size=10Gi `
  --set loki.persistence.storageClassName=gp2 `
  --set promtail.enabled=true `
  --set grafana.enabled=false `
  --set prometheus.enabled=false

Start-Sleep -Seconds 60
kubectl get pods -n monitoring | Select-String "loki"
# loki-0: Running 1/1
# loki-promtail-*: Running 1/1 (one per node)
```

---

### Step 4 - Expose Grafana via ALB
```powershell
# Nodes are in private subnets - must use ALB ingress, NOT LoadBalancer type
@"
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana-ingress
  namespace: monitoring
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80}]'
spec:
  ingressClassName: alb
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: prometheus-grafana
            port:
              number: 80
"@ | Out-File -FilePath grafana-ingress.yaml -Encoding ascii

kubectl apply -f grafana-ingress.yaml
Start-Sleep -Seconds 60

$GRAFANA_URL = "http://$(kubectl get ingress grafana-ingress -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
echo "Grafana URL: $GRAFANA_URL"
# Login: admin / admin123
```

---

### Step 5 - Add Loki Data Source in Grafana
1. Go to **Connections** -> **Data Sources** -> **Add data source**
2. Select **Loki**
3. Get the Loki cluster IP:
```powershell
kubectl get svc loki -n monitoring -o jsonpath='{.spec.clusterIP}'
```
4. Set URL to: `http://<loki-cluster-ip>:3100`
5. Click **Save & Test**

Note: Health check may show a parse error due to Grafana/Loki version mismatch.
This is cosmetic - the data source still works for queries.
Verify by going to Explore -> Loki -> run `{namespace="registration-app"}`

---

### Step 6 - Import Grafana Dashboards
Go to **Dashboards** -> **Import** and import:

| Dashboard ID | Name | Data Source |
|---|---|---|
| `15760` | Kubernetes / Views / Pods | Prometheus |
| `1860` | Node Exporter Full | Prometheus |
| `13639` | Loki Log Analytics | Loki |

---

### Step 7 - Verify Logs are Flowing
```powershell
kubectl exec -n monitoring loki-0 -- wget -qO- "http://localhost:3100/loki/api/v1/labels"
# Should return labels including: namespace, pod, container, app

kubectl exec -n monitoring loki-0 -- wget -qO- "http://localhost:3100/loki/api/v1/query?query=%7Bnamespace%3D%22registration-app%22%7D&limit=5"
# Should return log entries from backend pods
```

---

## MONITORING TROUBLESHOOTING

### Grafana/Loki health check parse error
Known version compatibility issue between Grafana 11.x and Loki 2.x.
Data source still works for queries despite the error.

### Loki PVC not binding
```powershell
kubectl get pvc -n monitoring
# If stuck in Pending, check EBS CSI driver is running:
kubectl get pods -n kube-system | Select-String "ebs-csi"
```

### No logs in Grafana Explore
```powershell
# Verify Promtail is running on all nodes
kubectl get pods -n monitoring | Select-String "promtail"
# Should show one pod per node (3 pods for 3 nodes)

# Verify Loki is receiving logs
kubectl exec -n monitoring loki-0 -- wget -qO- http://localhost:3100/ready
# Should return: ready
```

### Grafana LoadBalancer not accessible
Nodes are in private subnets - LoadBalancer type will not work.
Always use ALB ingress. Re-apply grafana-ingress.yaml:
```powershell
kubectl apply -f grafana-ingress.yaml
kubectl get ingress -n monitoring
```

### DESTROY - delete monitoring ingress before terraform destroy
```powershell
kubectl delete ingress grafana-ingress -n monitoring

## DESTROY
``````powershell
# Step 1 - Delete ingresses FIRST to let ALB controller clean up AWS resources
kubectl delete ingress --all -n registration-app
kubectl delete ingress --all -n argocd
kubectl delete ingress --all -n sonarqube
Start-Sleep -Seconds 90

# Step 2 - Delete leftover ALB security groups
``$VPC_ID = terraform -chdir=terraform output -raw vpc_id
``$sgs = aws ec2 describe-security-groups --region us-east-1 ``
  --filters "Name=vpc-id,Values=``$VPC_ID" ``
  --query 'SecurityGroups[?GroupName!=``default``].GroupId' --output text

``$sgs.Split("``t") | ForEach-Object {
  if (``$_) {
    Write-Host "Deleting SG: ``$_"
    aws ec2 delete-security-group --group-id ``$_ --region us-east-1
  }
}

# Step 3 - Destroy infrastructure
cd terraform
terraform destroy -auto-approve
cd ..
``````

---

## TROUBLESHOOTING

### Ingress has no ADDRESS after 5+ minutes
Most likely cause: ALB IAM policy not updated to latest version.
Re-run Step 3, then restart the controller:
``````powershell
kubectl delete pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
``````

### Backend ingress has no ADDRESS / SetRulePriorities 403 error
Most likely cause: ALB IAM policy missing SetRulePriorities permission.
Re-run Step 3, then restart the controller:
``````powershell
kubectl delete pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
Start-Sleep -Seconds 30
kubectl get ingress -n registration-app
``````

### Frontend cannot reach API / registration fails in browser
Most likely cause: REACT_APP_API_URL secret not set or pointing to old ALB URL.
1. Get current ALB URL: ``kubectl get ingress registration-app-ingress-frontend -n registration-app``
2. Update ``REACT_APP_API_URL`` secret in GitHub with the new ALB URL
3. Trigger rebuild:
``````powershell
git commit --allow-empty -m "ci: trigger rebuild with updated REACT_APP_API_URL"
git push
``````

### ArgoCD UI not accessible / ERR_CONNECTION_TIMED_OUT
Most likely cause: argocd-server service is LoadBalancer type (nodes are in private subnets).
Fix: patch to ClusterIP and use ALB ingress instead:
``````powershell
'{"spec":{"type":"ClusterIP"}}' | Out-File -FilePath patch-argocd-svc.json -Encoding ascii
kubectl patch svc argocd-server -n argocd --patch-file patch-argocd-svc.json
kubectl apply -f argocd-ingress.yaml
``````

### ArgoCD redirecting to HTTPS / health check returning 307
Most likely cause: server.insecure not set in argocd-cmd-params-cm.
Fix:
``````powershell
'{"data":{"server.insecure":"true"}}' | Out-File -FilePath patch-argocd-cm.json -Encoding ascii
kubectl patch configmap argocd-cmd-params-cm -n argocd --patch-file patch-argocd-cm.json
kubectl rollout restart deployment argocd-server -n argocd
``````

### ArgoCD app OutOfSync after deploy
``````powershell
kubectl get application -n argocd
# Force sync if needed:
kubectl patch application registration-app -n argocd --type merge -p '{"operation":{"sync":{"revision":"HEAD"}}}'
``````

### Targets unhealthy / 502 or 504 errors
Most likely cause: Istio intercepting ALB health checks.
Already fixed in Helm templates via excludeInboundPorts annotations.
``````powershell
kubectl get pods -n registration-app -o jsonpath='{.items[0].metadata.annotations}'
``````

### Pods 1/2 (Istio sidecar not injecting)
``````powershell
kubectl label namespace registration-app istio-injection=enabled --overwrite
kubectl rollout restart deployment/backend deployment/frontend -n registration-app
``````

### EBS CSI Driver stuck in CREATING
``````powershell
aws eks delete-addon --cluster-name registration-app-eks --addon-name aws-ebs-csi-driver --region us-east-1
# Wait until describe-addon returns ResourceNotFoundException, then:
terraform state rm aws_eks_addon.ebs_csi_driver
terraform apply
``````

### EBS CSI Controller pods in CrashLoopBackOff
Service account missing IRSA annotation. Fix:
``````powershell
kubectl annotate serviceaccount ebs-csi-controller-sa ``
  -n kube-system ``
  eks.amazonaws.com/role-arn=arn:aws:iam::958421185668:role/registration-app-eks-ebs-csi-role ``
  --overwrite
kubectl rollout restart deployment ebs-csi-controller -n kube-system
``````
Note: This is fixed permanently via service_account_role_arn in eks.tf - only needed if importing existing addon.

### terraform destroy fails on subnets/VPC
ALB security groups still attached. Run the destroy SG cleanup in the DESTROY section above.

### OIDC provider already exists on terraform apply
``````powershell
terraform import aws_iam_openid_connect_provider.github arn:aws:iam::958421185668:oidc-provider/token.actions.githubusercontent.com
terraform apply
``````

---

## FIXES ALREADY IN REPO (no action needed)

- ALB policy with DescribeListenerAttributes + SetRulePriorities: terraform/alb-iam-policy.json
- Istio health check bypass on backend pods: excludeInboundPorts 8000
- Istio health check bypass on frontend pods: excludeInboundPorts 80
- Split ingress with per-service healthcheck paths: helm/templates/ingress.yaml
- ServiceAccount created automatically by Helm: helm/templates/serviceaccount.yaml
- EBS CSI Driver IRSA annotation set automatically via service_account_role_arn in eks.tf
- GitHub Actions AWS auth via OIDC (no long-lived credentials): terraform/github-oidc.tf
- EKS access entries for GitHub Actions role (no aws-auth configmap editing): terraform/eks.tf
- EKS authentication mode API_AND_CONFIG_MAP with lifecycle ignore_changes: terraform/eks.tf
- ArgoCD server.insecure set via argocd-cmd-params-cm (not args patch): argocd-ingress.yaml
- SonarQube exposed via ALB ingress: sonarqube-ingress.yaml
- ArgoCD GitOps application pointing to helm/registration-app on main: argocd/registration-app.yaml

---

## ARCHITECTURE

Internet -> ALB (HTTP:80)
  /api/*  -> backend-service:8000  (3 pods, FastAPI + Istio sidecar)
  /*      -> frontend-service:80   (3 pods, React/Nginx + Istio sidecar)
                -> RDS PostgreSQL (registration-app-eks-db.cmd6quusggmv.us-east-1.rds.amazonaws.com)

Two Ingress resources share one ALB via group.name: registration-app
Each ingress has its own healthcheck-path (/api/health and /)

SonarQube -> separate ALB -> sonarqube pod (port 9000) -> embedded DB (eval only)
ArgoCD    -> separate ALB -> argocd-server pod (port 80, insecure mode)

---

## CI/CD

Push to main branch triggers:
  1. SonarQube static analysis (self-hosted on EKS)
  2. Docker build & push to Docker Hub (REACT_APP_API_URL baked into frontend image)
  3. Trivy vulnerability scan (blocks on unfixed CRITICAL CVEs)
  4. Helm deploy to EKS via OIDC (no AWS credentials stored in GitHub)
  5. Slack notification

ArgoCD watches the main branch and auto-syncs any Helm chart changes with selfHeal enabled.
"@ | Out-File -FilePath DEPLOYMENT.md -Encoding ascii