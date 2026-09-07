# ShopFlow — Django Microservices on EKS

A 5-service e-commerce backend (Django + DRF), a React frontend for AWS
Amplify, PostgreSQL storage (database-per-service), Docker images for every
service, a docker-compose stack for local integration testing, and Kubernetes
manifests for EKS.

## 1. The five microservices

| # | Service | Port | Responsibility | Owns DB |
|---|---------|------|-----------------|---------|
| 1 | **api-gateway** | 8000 | Single public entry point. Reverse-proxies `/api/<service>/...` to the right backend, forwards the JWT, aggregates `/health/`. No DB. | — |
| 2 | **user-service** | 8001 | Registration, login, JWT issuing (SimpleJWT), profile CRUD. Owns the `User` model. | `userdb` |
| 3 | **product-service** | 8002 | Product/category catalog, stock levels, an internal `reserve-stock` endpoint used only by order-service. | `productdb` |
| 4 | **order-service** | 8003 | Order placement orchestration: validates the cart, calls product-service to reserve stock + get authoritative pricing, persists the order, fires an event at notification-service. | `orderdb` |
| 5 | **notification-service** | 8004 | Receives `order-confirmed` events, stores + "sends" (logs, stubbed for SES/SendGrid) a notification, exposes a per-user notification feed. | `notifdb` |

## 2. How they communicate / request flow

```
Browser (React on Amplify)
   │  HTTPS, Authorization: Bearer <JWT>
   ▼
api-gateway  (only service exposed via ALB Ingress)
   │
   ├──/api/users/*────────────► user-service   ──► userdb
   ├──/api/products/*─────────► product-service──► productdb
   ├──/api/orders/*────────────► order-service   ──► orderdb
   └──/api/notifications/*────► notification-service ──► notifdb

Placing an order (order-service is the orchestrator):
  1. Client -> gateway -> order-service:  POST /api/orders/create/
  2. order-service -> product-service:    POST /internal/reserve-stock/  (X-Internal-Token header)
       - product-service atomically decrements stock, returns authoritative unit_price
  3. order-service persists Order + OrderItems in its own DB (orderdb)
  4. order-service -> notification-service: POST /events/order-confirmed/ (fire-and-forget)
  5. order-service -> gateway -> client:    201 Created, order JSON
```

Key design choices:
- **Database-per-service**: each service has its own logical Postgres database
  (`userdb`, `productdb`, `orderdb`, `notifdb`) — no service reads another
  service's tables directly, only its HTTP API. In compose they share one
  Postgres container (`db-init/init-multiple-dbs.sh` creates all 4 DBs); in
  EKS you'd point each at the same or separate RDS instances via `DB_HOST`.
- **Stateless JWT verification**: `user-service` issues JWTs (SimpleJWT). The
  other three business services verify the signature locally using a shared
  `JWT_SECRET_KEY` (see `*/authentication.py` — `StatelessJWTAuthentication`)
  instead of calling user-service on every request — faster and removes a
  hard runtime dependency on user-service being up.
- **Internal service-to-service auth**: `order-service → product-service`
  and `order-service → notification-service` calls carry an
  `X-Internal-Token` header (`INTERNAL_SERVICE_TOKEN`) instead of a user JWT,
  since the caller is a machine, not a logged-in user.
- **Gateway pattern**: the frontend only ever knows one hostname. Adding a
  6th microservice later means adding one line to `SERVICE_ROUTES` in
  `api-gateway/gateway/settings.py` — no frontend change needed.

## 3. Environment variables

Every service reads config from env vars (12-factor style) — see each
`settings.py`. Full reference lives in **`.env.example`**. The important ones:

| Variable | Used by | Meaning |
|---|---|---|
| `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME` | all 4 DB-backed services | Postgres connection (RDS endpoint in prod) |
| `DJANGO_SECRET_KEY` | all Django services | Django's internal crypto key |
| `JWT_SECRET_KEY` | user, product, order, notification, gateway | **Must be identical everywhere** — signs/verifies JWTs |
| `INTERNAL_SERVICE_TOKEN` | order, product, notification | Shared secret for machine-to-machine calls |
| `USER_SERVICE_URL`, `PRODUCT_SERVICE_URL`, `ORDER_SERVICE_URL`, `NOTIFICATION_SERVICE_URL` | gateway, order-service | Where to find peer services (compose container name / k8s Service DNS) |
| `ALLOWED_HOSTS`, `CORS_ALLOW_ALL_ORIGINS`, `CORS_ALLOWED_ORIGINS` | all | Django/host + browser CORS safety |
| `VITE_API_GATEWAY_URL` | frontend (build-time, set in Amplify env vars) | Gateway's public URL, e.g. `https://api.shopflow.example.com` |

## 4. Run everything locally with docker-compose

```bash
cd shopflow
cp .env.example .env
# edit .env if you want, defaults work out of the box

docker compose up --build
```

This builds all 5 Django images, starts Postgres (auto-creates the 4
databases via `db-init/init-multiple-dbs.sh`), runs migrations, and starts
every service. Verify everything is healthy:

```bash
curl http://localhost:8000/health/
# {"status":"ok","service":"api-gateway","downstream":{"users":"ok","products":"ok","orders":"ok","notifications":"ok"}}
```

Smoke-test the full request flow through the gateway only:

```bash
# 1) Register
curl -s -X POST http://localhost:8000/api/users/register/ \
  -H "Content-Type: application/json" \
  -d '{"username":"amina","email":"amina@example.com","password":"StrongPass123!"}' | tee /tmp/reg.json

TOKEN=$(python3 -c "import json;print(json.load(open('/tmp/reg.json'))['access'])")

# 2) Create a product directly against product-service admin/shell first (see below),
#    then list the catalog through the gateway
curl -s http://localhost:8000/api/products/ -H "Authorization: Bearer $TOKEN"

# 3) Place an order (assuming product id 1 exists with stock)
curl -s -X POST http://localhost:8000/api/orders/create/ \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"shipping_address":"123 Main St","items":[{"product_id":1,"quantity":2}]}'

# 4) Check the notification it triggered
curl -s http://localhost:8000/api/notifications/ -H "Authorization: Bearer $TOKEN"
```

Seed a product (create a superuser in product-service, then use its admin at
`http://localhost:8002/admin/`):

```bash
docker compose exec product-service python manage.py createsuperuser
```

Products support an optional image (Category → Add category first, then
Products → Add product → pick a file for **Image**). Uploaded files persist
in the `product_media` Docker volume and are served at
`http://localhost:8002/media/products/<filename>`; the API returns the full
URL as `image_url` on each product, which is what the frontend renders.
`PUBLIC_MEDIA_BASE_URL` (in `.env`) controls what host that URL points at —
it has to be something the *browser* can reach directly, not the internal
Docker hostname `product-service` that other containers use. This local-disk
storage is fine for one container but doesn't work across multiple replicas
in EKS — see the note in `k8s/03-product-service.yaml` about swapping it for
S3 before real production use.

Run the frontend against this stack:

```bash
cd frontend
cp .env.example .env      # VITE_API_GATEWAY_URL=http://localhost:8000
npm install
npm run dev                # http://localhost:3000
```

## 5. Deploying the frontend to AWS Amplify

1. Push `frontend/` to a Git repo (or the whole monorepo — Amplify lets you
   set the app root to `frontend/`).
2. Amplify Console → **New app → Host web app** → connect the repo/branch.
3. Amplify auto-detects `frontend/amplify.yml` (included) as the build spec.
4. Add environment variable in Amplify Console → App settings → Environment
   variables: `VITE_API_GATEWAY_URL = https://<your-alb-or-domain>`.
5. Deploy. Amplify builds with `npm ci && npm run build` and serves `dist/`.

## 6. Deploying the backend to EKS

1. **Build & push images** to ECR (repeat per service):
   ```bash
   aws ecr create-repository --repository-name shopflow/user-service
   docker build -t <ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com/shopflow/user-service:latest ./user-service
   aws ecr get-login-password --region <REGION> | docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com
   docker push <ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com/shopflow/user-service:latest
   ```
   Do the same for `product-service`, `order-service`, `notification-service`, `api-gateway`.
2. **Provision RDS PostgreSQL** (or one instance shared across the 4 DBs, matching compose).
3. **Apply manifests** (`k8s/` folder), in order:
   ```bash
   kubectl apply -f k8s/00-namespace.yaml
   kubectl apply -f k8s/01-secrets-configmap.yaml   # fill in real values first
   kubectl apply -f k8s/02-user-service.yaml
   kubectl apply -f k8s/03-product-service.yaml
   kubectl apply -f k8s/04-order-service.yaml
   kubectl apply -f k8s/05-notification-service.yaml
   kubectl apply -f k8s/06-api-gateway.yaml
   ```
4. Point `Route53` at the ALB the Ingress creates (requires the AWS Load
   Balancer Controller add-on installed on the cluster).
5. Update the Amplify env var `VITE_API_GATEWAY_URL` to that domain and redeploy the frontend.

## 7. Architecture diagram

`diagram/architecture_diagram.py` uses the [`diagrams`](https://diagrams.mingrammer.com/)
library (diagram-as-code) to render the full picture above as a PNG:

```bash
pip install diagrams   # also needs the Graphviz binary installed locally
cd diagram && python architecture_diagram.py
# -> shopflow_architecture.png
```

## 8. Project structure

```
shopflow/
├── api-gateway/            # Django reverse-proxy, single public entrypoint
├── user-service/           # Django + SimpleJWT auth service
├── product-service/        # Django catalog + stock service
├── order-service/          # Django order orchestrator
├── notification-service/   # Django event-driven notifications
├── frontend/                # React (Vite) UI, deployable on Amplify
├── db-init/                 # Postgres multi-database bootstrap script
├── k8s/                     # EKS manifests (namespace, config, 5x Deployment+Service, Ingress)
├── diagram/                 # diagrams-as-code architecture diagram
├── docker-compose.yml       # full local stack for integration testing
└── .env.example              # every env var, documented
```

## 9. Production hardening ideas (deliberately out of scope for this demo)

- Replace the synchronous `requests.post()` calls between order-service and
  notification-service with **SQS + a worker**, so a notification-service
  blip never risks the request/response cycle.
- Add a **saga/compensation step** in order-service: if stock reservation
  succeeds for item 1 but fails for item 2, release item 1's reserved stock.
- Real secrets via **AWS Secrets Manager + External Secrets Operator**,
  not plaintext `Secret` manifests.
- **HPA** (Horizontal Pod Autoscaler) per Deployment based on CPU/RPS.
- Rate limiting + request signing at the gateway.
