# ShopFlow — Microservices E-Commerce Platform

A 4-service Django microservices application (user, product, order, notification),
each with its own database, deployable three ways: **Docker Compose** (local dev),
**Minikube** (local Kubernetes), and **AWS EKS** (production, via Terraform).

## Architecture

```
                     ┌──────────────┐
                     │   Frontend   │
                     │   (React)    │
                     └──────┬───────┘
                            │
              ┌─────────────┴─────────────┐
              │   Gateway / Load Balancer  │
              │  (Django api-gateway, OR   │
              │   ALB path-based routing)  │
              └─────────────┬─────────────┘
                            │
       ┌──────────┬─────────┼─────────┬──────────────┐
       │          │         │         │              │
  ┌────▼───┐ ┌────▼────┐┌───▼────┐┌───▼──────────┐    │
  │  user  │ │ product ││ order  ││ notification │    │
  │service │ │ service ││service ││   service    │    │
  └────┬───┘ └────┬────┘└───┬────┘└───┬──────────┘    │
       │          │         │         │               │
       └──────────┴────┬────┴─────────┘               │
                        │                              │
                 ┌──────▼───────┐              ┌───────▼──────┐
                 │  PostgreSQL  │              │  S3 (images) │
                 │ (per-service │              │  [EKS only]  │
                 │   database)  │              └──────────────┘
                 └──────────────┘
```

order-service orchestrates checkout: it calls product-service to reserve
stock, then fires an event at notification-service once an order is
confirmed. Every service authenticates requests via a shared JWT secret —
no service calls back to user-service to validate a token on every request.

---

## Option 1 — Docker Compose (local development)

The fastest way to run everything on your own machine, no Kubernetes needed.

### Prerequisites
- Docker + Docker Compose installed

### Steps

```bash
git clone <your-repo-url>
cd shopflow

cp .env.example .env
# edit .env if you want different ports/credentials - defaults work out of the box

docker compose up --build
```

This builds all 5 images (4 services + gateway), starts Postgres (auto-creating
`userdb`, `productdb`, `orderdb`, `notifdb` via `db-init/init-multiple-dbs.sh`),
runs migrations, and starts every service.

### Verify it's working

```bash
curl http://localhost:8000/health/
# {"status":"ok","service":"api-gateway","downstream":{"users":"ok","products":"ok","orders":"ok","notifications":"ok"}}
```

### Run the frontend

```bash
cd frontend
cp .env.example .env      # VITE_API_GATEWAY_URL=http://localhost:8000
npm install
npm run dev                # http://localhost:3000
```

### Seed a product

```bash
docker compose exec product-service python manage.py createsuperuser
# then visit http://localhost:8002/admin/ and add a product
```

### Tear down

```bash
docker compose down -v   # -v also wipes the database volume
```

---

## Option 2 — Minikube (local Kubernetes)

Same application, running under real Kubernetes objects (Deployments,
Services, ConfigMaps, Secrets, PVCs) — no AWS account needed.

### Prerequisites
```bash
brew install minikube kubectl
minikube start --cpus=4 --memory=8192
```

### Steps

**1. Build images directly into minikube's own Docker daemon** (no registry needed):
```bash
eval $(minikube docker-env)

docker build -t user-service:local ./user-service
docker build -t product-service:local ./product-service
docker build -t order-service:local ./order-service
docker build -t notification-service:local ./notification-service
docker build -t api-gateway:local ./api-gateway
```

**2. Deploy namespace, database, config:**
```bash
cd k8s/minikube
kubectl apply -f 00-namespace.yaml
kubectl apply -f 01-postgres-init-configmap.yaml
kubectl apply -f 02-postgres.yaml       # Postgres as a StatefulSet with a real PVC
kubectl apply -f 03-secrets-configmap.yaml

kubectl -n shopflow rollout status statefulset/postgres
```

**3. Deploy the microservices:**
```bash
kubectl apply -f 04-user-service.yaml
kubectl apply -f 05-order-service.yaml
kubectl apply -f 06-product-service.yaml
kubectl apply -f 07-notification-service.yaml
kubectl apply -f 08-api-gateway.yaml

kubectl -n shopflow get pods -w
```

**4. Get the URLs and wire up the frontend:**
```bash
minikube service api-gateway -n shopflow --url
```
This must stay running in its own terminal tab (minikube's Docker driver
requires an active tunnel for NodePort access). Use the printed URL as
`VITE_API_GATEWAY_URL` in `frontend/.env`, then `npm run dev`.

### Verify
```bash
GATEWAY_URL=$(minikube service api-gateway -n shopflow --url)
curl -s $GATEWAY_URL/health/
```

### Cleanup
```bash
kubectl delete namespace shopflow
minikube stop   # or: minikube delete
```

---

## Option 3 — AWS EKS (production)

Real infrastructure: VPC, EKS cluster, Aurora PostgreSQL, S3, ALB — all
provisioned via Terraform.

> ⚠️ **This incurs real AWS cost.** EKS control plane, NAT Gateways, an
> Application Load Balancer, and an Aurora cluster are all billed hourly
> regardless of traffic. Set a budget alert before you start, and run
> `terraform destroy` when you're done experimenting.

### Prerequisites
- AWS account + credentials configured (`aws configure`)
- `terraform`, `kubectl`, `helm`, `eksctl` installed

### 1. Provision the infrastructure

```bash
cd terraform/
terraform init
terraform plan
terraform apply
```

This creates: VPC with public/private/database subnets across 3 AZs, NAT
Gateways, an EKS cluster + managed node group, an Aurora PostgreSQL cluster
(writer + read replica), an S3 bucket for product images, the OIDC provider
and IAM roles needed for IRSA (IAM Roles for Service Accounts).

### 2. Point kubectl at the new cluster

```bash
aws eks update-kubeconfig --region <your-region> --name <your-cluster-name>
kubectl get nodes
```

### 3. Create the databases

RDS/Aurora provisions the *instance*, not the databases your app expects —
`migrate` only creates tables inside a database that already exists:

```bash
# Since Aurora lives in a private subnet, run this from inside the cluster
# (not your laptop) via a one-shot pod:
kubectl run db-init --rm -it --restart=Never --image=postgres:16-alpine \
  -- psql -h <aurora-cluster-endpoint> -U <db-username> -d postgres \
  -c "CREATE DATABASE userdb; CREATE DATABASE productdb; CREATE DATABASE orderdb; CREATE DATABASE notifdb;"
```

### 4. Build and push images to ECR

```bash
aws ecr create-repository --repository-name shopflow/user-service
# repeat for product-service, order-service, notification-service

aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <account-id>.dkr.ecr.<region>.amazonaws.com

docker build -t <account-id>.dkr.ecr.<region>.amazonaws.com/shopflow/user-service:latest ./user-service
docker push <account-id>.dkr.ecr.<region>.amazonaws.com/shopflow/user-service:latest
# repeat per service
```

### 5. Install the AWS Load Balancer Controller

Required before any `Ingress` can actually provision an ALB:

```bash
kubectl create serviceaccount aws-load-balancer-controller -n kube-system
kubectl annotate serviceaccount aws-load-balancer-controller -n kube-system \
  eks.amazonaws.com/role-arn=$(terraform output -raw alb_controller_role_arn)

helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=<your-cluster-name> \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

kubectl get deployment -n kube-system aws-load-balancer-controller
```

### 6. Deploy the application

```bash
kubectl apply -f k8s/00-namespace.yaml
kubectl apply -f k8s/01-secrets-configmap.yaml   # fill in real DB endpoint, S3 bucket, secrets
kubectl apply -f k8s/02-user-service.yaml
kubectl apply -f k8s/03-product-service.yaml     # includes the ServiceAccount for S3 IRSA
kubectl apply -f k8s/04-order-service.yaml
kubectl apply -f k8s/05-notification-service.yaml
kubectl apply -f k8s/06-ingress.yaml             # ALB, path-based routing to all 4 services

kubectl -n shopflow get ingress -w
```

Wait for the `ADDRESS` column to populate (1-3 minutes) — that's your ALB's
public DNS name.

### 7. Wire up the frontend

Point `VITE_API_GATEWAY_URL` at the ALB's DNS name (or a CloudFront/custom
domain in front of it, if you set one up) and deploy the frontend to
Amplify, or run it locally against the real backend for testing.

### Verify

```bash
ALB_URL=$(kubectl -n shopflow get ingress shopflow-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl http://$ALB_URL/api/users/register/ -H "Content-Type: application/json" \
  -d '{"username":"test","email":"test@example.com","password":"StrongPass123!"}'
```

### Tearing it down

**Delete Kubernetes-managed resources first** — the ALB and its security
groups are created by the AWS Load Balancer Controller, not Terraform, so
`terraform destroy` doesn't know they exist and will fail with dependency
errors on your subnets/IGW if you skip this step:

```bash
kubectl delete ingress shopflow-ingress -n shopflow

# wait ~2 min, then confirm it's actually gone:
aws elbv2 describe-load-balancers --query "LoadBalancers[?contains(LoadBalancerName, 'shopflow')]"
# should return []
```

Empty the S3 bucket (Terraform won't delete a non-empty bucket):
```bash
aws s3 rm s3://<your-bucket-name> --recursive
```

Then:
```bash
terraform destroy
```

---

## Troubleshooting

Real issues encountered building this, and their fixes:

| Symptom | Cause | Fix |
|---|---|---|
| `500` on register, generic error page | Migrations never generated for custom models | `python manage.py makemigrations` before first deploy |
| `relation "accounts_user" does not exist` after a fix | Stale Docker/K8s volume with old migration history | Wipe the volume (`docker compose down -v` / delete the PVC), start fresh |
| Every request through api-gateway 500s | Gateway's `INSTALLED_APPS` missing `django.contrib.auth`/`contenttypes` | DRF's `perform_authentication()` needs `AnonymousUser`, which needs `ContentType` registered |
| `CORS_ALLOWED_ORIGINS` causes Django to refuse to start | Set to `"*"` — invalid for this setting | Use `CORS_ALLOW_ALL_ORIGINS=True` for wildcard, or list real origins |
| Browser shows "CORS error" but `curl` gets a real response | Error responses (500s, stale ConfigMap values) lack CORS headers | Check the *actual* response with `curl -v` first — CORS is often a symptom, not the cause |
| `ImagePullBackOff` in minikube | Image built with host Docker, not minikube's daemon | `eval $(minikube docker-env)` before building |
| Product image upload 500s (local disk) | Container's non-root user doesn't own the media directory | `chown` the media dir to the app user in the Dockerfile |
| ALB never provisions (`ADDRESS` stays blank) | AWS Load Balancer Controller not installed, or subnets missing `kubernetes.io/role/elb` tag | Install the controller; tag public subnets for ALB, private for internal-facing |
| `AssumeRoleWithWebIdentity ... Request ARN is invalid` | ServiceAccount annotated with the OIDC *provider* ARN instead of an IAM *role* ARN | Use the role ARN (`arn:...:role/...`), not the provider ARN (`arn:...:oidc-provider/...`) |
| `terraform destroy` fails on subnets/IGW with `DependencyViolation` | ALB created by the K8s controller isn't tracked by Terraform | `kubectl delete ingress` first, confirm the ALB is gone, then destroy |

---

## Project Structure

```
shopflow/
├── user-service/            # Django - auth, JWT issuance, profiles
├── product-service/         # Django - catalog, stock, S3 image storage
├── order-service/           # Django - order orchestration
├── notification-service/    # Django - event-driven notifications
├── api-gateway/              # Django reverse-proxy (compose/minikube only)
├── frontend/                  # React (Vite) UI
├── db-init/                   # Postgres multi-database bootstrap script
├── k8s/                       # EKS manifests (ALB Ingress, no gateway)
├── k8s/minikube/               # Minikube manifests (StatefulSet Postgres, gateway-routed)
├── terraform/                  # VPC, EKS, RDS, S3, IAM/IRSA
├── docker-compose.yml
└── .env.example
```