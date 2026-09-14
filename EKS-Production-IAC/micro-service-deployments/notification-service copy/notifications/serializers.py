from rest_framework import serializers

from .models import Notification


class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notification
        fields = ["id", "user_id", "event_type", "message", "is_read", "created_at"]


class OrderConfirmedEventSerializer(serializers.Serializer):
    user_id = serializers.IntegerField()
    order_id = serializers.IntegerField()
    total_amount = serializers.CharField()
