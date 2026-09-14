from django.urls import path

from .views import CreateOrderView, OrderDetailView, OrderListView, health

urlpatterns = [
    path("health/", health),
    path("api/orders/", OrderListView.as_view(), name="order-list"),
    path("api/orders/create/", CreateOrderView.as_view(), name="order-create"),
    path("api/orders/<int:pk>/", OrderDetailView.as_view(), name="order-detail"),
]
