from django.urls import path
from rest_framework.routers import DefaultRouter

from .views import CategoryViewSet, ProductViewSet, ReserveStockView, health

router = DefaultRouter()
router.register("api/products", ProductViewSet, basename="product")
router.register("api/categories", CategoryViewSet, basename="category")

urlpatterns = [
    path("health/", health),
    path("api/products/internal/reserve-stock/", ReserveStockView.as_view(), name="reserve-stock"),
] + router.urls
