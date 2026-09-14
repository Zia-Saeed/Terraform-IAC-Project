from django.conf import settings
from django.http import JsonResponse
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Notification
from .serializers import NotificationSerializer, OrderConfirmedEventSerializer
from .services import send_email


def health(request):
    return JsonResponse({"status": "ok", "service": "notification-service"})


class NotificationListView(generics.ListAPIView):
    """A user's own notification feed - GET /api/notifications/"""
    serializer_class = NotificationSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Notification.objects.filter(user_id=self.request.user.id).order_by("-created_at")


class OrderConfirmedEventView(APIView):
    """Internal event receiver called by order-service right after an
    order is confirmed. Validated with the shared internal-service token,
    the same pattern product-service uses for its reserve-stock endpoint."""
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        if request.headers.get("X-Internal-Token") != settings.INTERNAL_SERVICE_TOKEN:
            return Response({"detail": "Forbidden: invalid internal service token"}, status=403)

        serializer = OrderConfirmedEventSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        d = serializer.validated_data

        message = f"Your order #{d['order_id']} for ${d['total_amount']} has been confirmed!"
        notif = Notification.objects.create(
            user_id=d["user_id"], event_type=Notification.EventType.ORDER_CONFIRMED, message=message
        )
        send_email(d["user_id"], "Order Confirmed", message)
        return Response(NotificationSerializer(notif).data, status=status.HTTP_201_CREATED)
