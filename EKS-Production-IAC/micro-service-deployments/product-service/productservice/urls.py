from django.conf import settings
from django.contrib import admin
from django.urls import include, path
from django.views.static import serve as serve_static

urlpatterns = [
    path("admin/", admin.site.urls),
    path("", include("products.urls")),
]

# Serve uploaded product images. Django's usual advice is "only do this
# when DEBUG=True, use a real web server otherwise" - but this project has
# no separate static/media server (nginx, S3, CDN) in front of it, and we
# run with DEBUG=False by default, so we serve media unconditionally here.
# django.views.static.serve is NOT hardened/optimized for production traffic
# (no caching headers, no range requests, single-threaded file reads) - fine
# for a demo or low-traffic internal tool, but swap this for S3 + CloudFront
# (or nginx/whatever sits in front of the pod) before real production use.
urlpatterns += [
    path("media/<path:path>", serve_static, {"document_root": settings.MEDIA_ROOT}),
]
