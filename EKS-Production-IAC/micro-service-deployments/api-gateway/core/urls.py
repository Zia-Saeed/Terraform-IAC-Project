from django.urls import path, re_path

from .views import health, proxy

urlpatterns = [
    path("health/", health),
    re_path(r"^api/(?P<prefix>[\w-]+)/(?P<path>.*)$", proxy),
]
