# Deploying ShopFlow on Minikube

This mirrors the EKS setup in `k8s/` but swaps out everything that assumed
AWS: RDS becomes an in-cluster Postgres Deployment, ECR becomes images built
directly into minikube's own Docker daemon, and the ALB Ingress becomes a
plain NodePort Service.

## What gets exposed, and why

**Only `api-gateway` is exposed outside the cluster.** Every other Service
(`user-service`, `product-service`, `order-service`, `notification-service`,
`postgres`) is `ClusterIP` - reachable by other pods via Kubernetes' internal
DNS (e.g. `http://user-service:8001`) but invisible outside the cluster.
This is the same gateway pattern from docker-compose, just enforced at the
network layer this time instead of by convention: the frontend has exactly
one hostname to know about, and adding a 6th microservice later never
touches the frontend.

The one deliberate exception is **`product-service`**, also exposed via
NodePort - not for its JSON API (that still goes through the gateway like
everything else), but because uploaded product images need a URL your
*browser* can load directly, and the gateway doesn't proxy binary file
downloads (only the JSON `/api/*` routes - see `api-gateway/core/views.py`).

## Prerequisites

```bash
brew install minikube kubectl        # or your OS's equivalent
minikube start --cpus=4 --memory=8192
kubectl get nodes                     # sanity check - should show "Ready"
```

## Step 1 — Build images directly into minikube (no registry needed)

Minikube runs its own internal Docker daemon, separate from your host's.
Point your shell's `docker` CLI at it for this session, then build normally
- the images land inside the cluster with no push/pull step required:

```bash
eval $(minikube docker-env)

cd eks-microservices-project
docker build -t user-service:local ./user-service
docker build -t product-service:local ./product-service
docker build -t order-service:local ./order-service
docker build -t notification-service:local ./notification-service
docker build -t api-gateway:local ./api-gateway

docker images | grep -E "user-service|product-service|order-service|notification-service|api-gateway"
```

(Every future code change: re-run the relevant `docker build`, then
`kubectl rollout restart deployment/<service> -n shopflow` to pick it up.)

> Alternative if you'd rather build with your normal host Docker: build the
> images as usual, then `minikube image load user-service:local` (repeat per
> service) to copy them into the cluster instead of using `docker-env`.

## Step 2 — Deploy the namespace, database, and config

```bash
cd k8s/minikube
kubectl apply -f 00-namespace.yaml
kubectl apply -f 01-postgres-init-configmap.yaml
kubectl apply -f 02-postgres.yaml
kubectl apply -f 03-secrets-configmap.yaml   # edit the placeholder secret values first if you want

kubectl -n shopflow rollout status statefulset/postgres
```

Postgres runs as a `StatefulSet` (not a `Deployment`) specifically because
it's stateful — its `volumeClaimTemplates` auto-creates a uniquely-named PVC
(`postgres-data-postgres-0`) that survives pod restarts/reschedules, unlike
a plain `emptyDir` which would wipe your data every time the pod moved.
Verify the persistent storage actually got provisioned:

```bash
kubectl -n shopflow get pvc
kubectl -n shopflow get pv
```

## Step 3 — Deploy the five microservices

```bash
kubectl apply -f 04-user-service.yaml
kubectl apply -f 05-order-service.yaml
kubectl apply -f 06-product-service.yaml
kubectl apply -f 07-notification-service.yaml
kubectl apply -f 08-api-gateway.yaml

kubectl -n shopflow get pods -w
```

Wait until every pod shows `1/1 Running` (Ctrl+C once they settle - the
`migrate` step in each container's entrypoint takes a few seconds).

If something sticks in `CrashLoopBackOff` or `ImagePullBackOff`:

```bash
kubectl -n shopflow logs deployment/<service-name>
kubectl -n shopflow describe pod <pod-name>
```

`ImagePullBackOff` almost always means Step 1's `eval $(minikube docker-env)`
wasn't active in the shell you ran `docker build` from - rebuild with it set.

## Step 4 — Get the URLs and wire up the frontend

```bash
minikube service api-gateway -n shopflow --url
minikube service product-service -n shopflow --url
```

Take the **api-gateway** URL and use it as `VITE_API_GATEWAY_URL` for the
frontend (same as `VITE_API_GATEWAY_URL=http://localhost:8000` was for
docker-compose):

```bash
cd frontend
echo "VITE_API_GATEWAY_URL=<url from minikube service api-gateway>" > .env
npm install && npm run dev
```

Take the **product-service** URL and paste it into `PUBLIC_MEDIA_BASE_URL`
in `03-secrets-configmap.yaml` (replacing the placeholder), then re-apply
and restart product-service so it picks up the change:

```bash
kubectl apply -f 03-secrets-configmap.yaml
kubectl -n shopflow rollout restart deployment/product-service
```

> `minikube service --url` uses `minikube tunnel`/the node IP under the
> hood, so the port stays fixed (30000 for the gateway, 30002 for
> product-service - set in each Service's `nodePort`) but the host part can
> change if you restart minikube itself. Re-run the command if things stop
> resolving after a `minikube stop` / `minikube start`.

## Step 5 — Smoke test

```bash
GATEWAY_URL=$(minikube service api-gateway -n shopflow --url)
curl -s $GATEWAY_URL/health/
# {"status":"ok","service":"api-gateway","downstream":{"users":"ok","products":"ok","orders":"ok","notifications":"ok"}}
```

Then repeat the register → list products → create order → check
notifications flow from the main README, just pointed at `$GATEWAY_URL`
instead of `localhost:8000`.

## Cleaning up

```bash
kubectl delete namespace shopflow    # deletes everything in one shot, including the PVCs' data
minikube stop                         # or: minikube delete, to remove the whole VM
```
