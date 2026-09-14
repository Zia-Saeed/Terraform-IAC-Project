import requests
from django.conf import settings
from django.db import transaction
from django.http import JsonResponse
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Order, OrderItem
from .serializers import CreateOrderSerializer, OrderSerializer


def health(request):
    return JsonResponse({"status": "ok", "service": "order-service"})


class OrderListView(generics.ListAPIView):
    """A user's own order history."""
    serializer_class = OrderSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Order.objects.filter(user_id=self.request.user.id).order_by("-created_at")


class OrderDetailView(generics.RetrieveAPIView):
    serializer_class = OrderSerializer
    permission_classes = [permissions.IsAuthenticated]
    queryset = Order.objects.all()

    def get_queryset(self):
        return Order.objects.filter(user_id=self.request.user.id)


class CreateOrderView(APIView):
    """
    Orchestrates order placement across services:
      1. Validate the request body.
      2. For each line item, call product-service to atomically reserve
         stock and get the authoritative price (never trust client-supplied price).
      3. Persist the Order + OrderItems locally, in a DB transaction.
      4. Fire-and-forget a notification event to notification-service.
    If stock reservation fails partway through, the order is marked FAILED
    rather than left in limbo (a production system would also compensate /
    release any already-reserved stock - noted in README as a next step).
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        serializer = CreateOrderSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        order = Order.objects.create(
            user_id=request.user.id,
            status=Order.Status.PENDING,
            shipping_address=data["shipping_address"],
        )

        total = 0
        reserved_items = []
        internal_headers = {"X-Internal-Token": settings.INTERNAL_SERVICE_TOKEN}

        for item in data["items"]:
            try:
                resp = requests.post(
                    f"{settings.PRODUCT_SERVICE_URL}/api/products/internal/reserve-stock/",
                    json={"product_id": item["product_id"], "quantity": item["quantity"]},
                    headers=internal_headers,
                    timeout=5,
                )
            except requests.RequestException:
                order.status = Order.Status.FAILED
                order.save(update_fields=["status"])
                return Response({"detail": "product-service unreachable"}, status=status.HTTP_502_BAD_GATEWAY)

            if resp.status_code != 200:
                order.status = Order.Status.FAILED
                order.save(update_fields=["status"])
                return Response(
                    {"detail": "Could not reserve stock", "product_service_response": resp.json()},
                    status=status.HTTP_409_CONFLICT,
                )

            payload = resp.json()
            unit_price = payload["unit_price"]
            reserved_items.append(
                OrderItem(
                    order=order,
                    product_id=item["product_id"],
                    product_name=payload["name"],
                    unit_price=unit_price,
                    quantity=item["quantity"],
                )
            )
            total += float(unit_price) * item["quantity"]

        with transaction.atomic():
            OrderItem.objects.bulk_create(reserved_items)
            order.total_amount = total
            order.status = Order.Status.CONFIRMED
            order.save(update_fields=["total_amount", "status"])

        # Notify asynchronously-ish: a network blip here should not fail the
        # order itself, so we swallow errors (a queue like SQS would remove
        # this trade-off entirely - see README "Production hardening").
        try:
            requests.post(
                f"{settings.NOTIFICATION_SERVICE_URL}/api/notifications/events/order-confirmed/",
                json={
                    "user_id": order.user_id,
                    "order_id": order.id,
                    "total_amount": str(order.total_amount),
                },
                headers=internal_headers,
                timeout=3,
            )
        except requests.RequestException:
            pass

        return Response(OrderSerializer(order).data, status=status.HTTP_201_CREATED)
