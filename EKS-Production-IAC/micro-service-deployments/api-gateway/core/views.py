import requests
from django.conf import settings
from django.http import JsonResponse
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response


def health(request):
    """Gateway's own liveness check + a fan-out check of every downstream
    service, handy for a quick 'is the whole system up' glance."""
    downstream = {}
    for name, base_url in settings.SERVICE_ROUTES.items():
        if name == "categories":
            continue  # same host as products, no need to check twice
        try:
            r = requests.get(f"{base_url}/health/", timeout=2)
            downstream[name] = "ok" if r.status_code == 200 else f"error ({r.status_code})"
        except requests.RequestException as exc:
            downstream[name] = f"unreachable ({exc.__class__.__name__})"
    return JsonResponse({"status": "ok", "service": "api-gateway", "downstream": downstream})


@api_view(["GET", "POST", "PUT", "PATCH", "DELETE"])
@permission_classes([AllowAny])
def proxy(request, prefix, path=""):
    """
    Generic reverse proxy: /api/<prefix>/<path> -> SERVICE_ROUTES[prefix]/api/<prefix>/<path>
    The Authorization header (the user's JWT) is forwarded as-is, so
    downstream services can verify it themselves without calling back here.
    """
    base_url = settings.SERVICE_ROUTES.get(prefix)
    if not base_url:
        return Response({"detail": f"Unknown service route '{prefix}'"}, status=404)

    target_url = f"{base_url}/api/{prefix}/{path}"
    forward_headers = {}
    if "HTTP_AUTHORIZATION" in request.META:
        forward_headers["Authorization"] = request.META["HTTP_AUTHORIZATION"]
    forward_headers["Content-Type"] = "application/json"

    try:
        resp = requests.request(
            method=request.method,
            url=target_url,
            headers=forward_headers,
            json=request.data if request.data else None,
            params=request.query_params,
            timeout=settings.GATEWAY_TIMEOUT_SECONDS,
        )
    except requests.RequestException as exc:
        return Response({"detail": f"Upstream service '{prefix}' unreachable", "error": str(exc)}, status=502)

    try:
        body = resp.json()
    except ValueError:
        body = {"detail": resp.text}
    return Response(body, status=resp.status_code)
