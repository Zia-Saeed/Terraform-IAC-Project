from django.conf import settings
from rest_framework import serializers

from .models import Category, Product


class CategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = Category
        fields = ["id", "name"]


class ProductSerializer(serializers.ModelSerializer):
    category_name = serializers.CharField(source="category.name", read_only=True)
    # image.url alone is only a path like "/media/products/foo.jpg" - the
    # frontend needs a full, browser-reachable URL. We can't rely on DRF's
    # default request.build_absolute_uri() here because most requests to
    # this serializer arrive via the api-gateway's internal proxy call
    # (from "http://product-service:8002", a hostname only other containers
    # can resolve) rather than directly from the browser. PUBLIC_MEDIA_BASE_URL
    # is the host the browser can actually reach.
    image_url = serializers.SerializerMethodField()

    class Meta:
        model = Product
        fields = [
            "id", "name", "description", "category", "category_name",
            "price", "stock_quantity", "sku", "image", "image_url",
            "is_active", "created_at", "updated_at",
        ]
        extra_kwargs = {"image": {"write_only": True, "required": False}}

    def get_image_url(self, obj):
        if not obj.image:
            return None
        return f"{settings.PUBLIC_MEDIA_BASE_URL}{obj.image.url}"


class StockReserveSerializer(serializers.Serializer):
    """Payload order-service sends when an order is placed."""
    product_id = serializers.IntegerField()
    quantity = serializers.IntegerField(min_value=1)
