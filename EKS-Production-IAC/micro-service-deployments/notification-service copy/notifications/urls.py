from django.urls import path

from .views import NotificationListView, OrderConfirmedEventView, health

urlpatterns = [
    path("health/", health),
    path("api/notifications/", NotificationListView.as_view(), name="notification-list"),
    path("api/notifications/events/order-confirmed/", OrderConfirmedEventView.as_view(), name="order-confirmed-event"),
]
