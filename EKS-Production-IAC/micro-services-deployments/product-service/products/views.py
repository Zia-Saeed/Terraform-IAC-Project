from django.conf import settings
from django.http import JsonResponse
from django.shortcuts import get_object_or_404
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework import generics, permissions, status, viewsets
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Category, Product
from .serializers import CategorySerializer, ProductSerializer, StockReserveSerializer


def health(request):
    return JsonResponse({"status": "ok", "service": "product-service"})


class CategoryViewSet(viewsets.ModelViewSet):
    queryset = Category.objects.all()
    serializer_class = CategorySerializer


class ProductViewSet(viewsets.ModelViewSet):
    """Full CRUD catalog. Anyone can read; only authenticated users can write."""
    queryset = Product.objects.filter(is_active=True)
    serializer_class = ProductSerializer
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ["category", "is_active"]


class ReserveStockView(APIView):
    """Internal endpoint called ONLY by order-service when an order is placed.
    Protected by a shared internal-service token (not a user JWT), since the
    caller here is another microservice, not an end user."""
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        if request.headers.get("X-Internal-Token") != settings.INTERNAL_SERVICE_TOKEN:
            return Response({"detail": "Forbidden: invalid internal service token"}, status=403)

        serializer = StockReserveSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        product = get_object_or_404(Product, id=serializer.validated_data["product_id"])
        qty = serializer.validated_data["quantity"]

        if product.stock_quantity < qty:
            return Response(
                {"detail": f"Insufficient stock for {product.name}", "available": product.stock_quantity},
                status=status.HTTP_409_CONFLICT,
            )

        product.stock_quantity -= qty
        product.save(update_fields=["stock_quantity"])
        return Response(
            {"product_id": product.id, "name": product.name, "unit_price": str(product.price), "remaining_stock": product.stock_quantity}
        )
