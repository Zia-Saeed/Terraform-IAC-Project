FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential libpq-dev curl \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# The container runs as a non-root user for security, but everything copied
# in above (via COPY . .) is owned by root, and product-service is the only
# service that writes to its own filesystem at runtime (product images -
# see MEDIA_ROOT in productservice/settings.py). Without this chown,
# uploading a product image fails with a PermissionError the moment Django
# tries to create the media/products/ directory, which surfaces to the
# browser as a plain 500.
#
# UID/GID are pinned to 1000 (rather than left to adduser's default) so that
# Kubernetes' pod-level `securityContext.fsGroup: 1000` (see k8s/minikube/)
# can grant this exact user write access to a mounted PersistentVolumeClaim -
# fsGroup only helps if it actually matches the container's runtime group.
RUN mkdir -p /app/media && \
    groupadd -g 1000 appuser && \
    useradd -u 1000 -g appuser -M -s /usr/sbin/nologin appuser && \
    chown -R appuser:appuser /app
USER appuser

EXPOSE 8002

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD curl -f http://localhost:8002/health/ || exit 1

CMD ["sh", "-c", "python manage.py migrate --noinput && gunicorn productservice.wsgi:application --bind 0.0.0.0:8002 --workers 3"]
