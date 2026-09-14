"""
API Gateway settings.
The ONLY service the frontend (deployed on Amplify) talks to. It has no
database of its own - it authenticates nothing itself and instead forwards
requests (and the client's Authorization header) to the correct downstream
microservice based on URL prefix, then relays the response back untouched.
This keeps CORS configuration, rate limiting, and logging in one place.
"""
import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent

SECRET_KEY = os.environ.get("DJANGO_SECRET_KEY", "dev-insecure-secret-key")
DEBUG = os.environ.get("DJANGO_DEBUG", "False") == "True"
ALLOWED_HOSTS = os.environ.get("ALLOWED_HOSTS", "*").split(",")

INSTALLED_APPS = [
    # auth + contenttypes are required even though the gateway has no models
    # or users of its own: DRF's perform_authentication() runs on every
    # request (even AllowAny ones) and falls back to
    # django.contrib.auth.models.AnonymousUser, which imports the
    # ContentType model - that import fails with a RuntimeError unless
    # both apps are registered here.
    "django.contrib.contenttypes",
    "django.contrib.auth",
    "django.contrib.staticfiles",
    "rest_framework",
    "corsheaders",
    "core",
]

MIDDLEWARE = [
    "corsheaders.middleware.CorsMiddleware",
    "django.middleware.common.CommonMiddleware",
]


ROOT_URLCONF = "gateway.urls"
WSGI_APPLICATION = "gateway.wsgi.application"
TEMPLATES = []

STATIC_URL = "static/"
DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"
USE_TZ = True

CORS_ALLOW_ALL_ORIGINS = os.environ.get("CORS_ALLOW_ALL_ORIGINS", "True") == "True"
CORS_ALLOWED_ORIGINS = [o for o in os.environ.get("CORS_ALLOWED_ORIGINS", "").split(",") if o]

# --- Downstream microservice locations ---
# In EKS these resolve via Kubernetes Service DNS, e.g.
#   http://user-service.default.svc.cluster.local:8001
# In docker-compose they resolve via the compose service name.
SERVICE_ROUTES = {
    "users": os.environ.get("USER_SERVICE_URL", "http://user-service:8001"),
    "products": os.environ.get("PRODUCT_SERVICE_URL", "http://product-service:8002"),
    "categories": os.environ.get("PRODUCT_SERVICE_URL", "http://product-service:8002"),
    "orders": os.environ.get("ORDER_SERVICE_URL", "http://order-service:8003"),
    "notifications": os.environ.get("NOTIFICATION_SERVICE_URL", "http://notification-service:8004"),
}

GATEWAY_TIMEOUT_SECONDS = float(os.environ.get("GATEWAY_TIMEOUT_SECONDS", 10))
SERVICE_NAME = "api-gateway"
