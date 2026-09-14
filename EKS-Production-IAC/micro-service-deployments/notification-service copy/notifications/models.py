from django.db import models


class Notification(models.Model):
    class EventType(models.TextChoices):
        ORDER_CONFIRMED = "ORDER_CONFIRMED", "Order Confirmed"
        ORDER_FAILED = "ORDER_FAILED", "Order Failed"
        WELCOME = "WELCOME", "Welcome"

    user_id = models.IntegerField()
    event_type = models.CharField(max_length=30, choices=EventType.choices)
    message = models.CharField(max_length=255)
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"[{self.event_type}] -> user {self.user_id}"
