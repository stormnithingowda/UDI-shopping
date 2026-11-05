from django.db import models
from .models import Order

class RazorpayPayment(models.Model):
    class Status(models.TextChoices):
        CREATED = 'created', 'Created'
        AUTHORIZED = 'authorized', 'Authorized'
        CAPTURED = 'captured', 'Captured'
        FAILED = 'failed', 'Failed'
    order = models.OneToOneField(Order, on_delete=models.PROTECT, related_name='payment')
    razorpay_order_id = models.CharField(max_length=100, unique=True)
    razorpay_payment_id = models.CharField(max_length=100, unique=True, null=True, blank=True)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.CREATED)
    amount_paise = models.PositiveBigIntegerField()
    currency = models.CharField(max_length=3, default='INR')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

class RazorpayWebhookEvent(models.Model):
    event_id = models.CharField(max_length=150, unique=True)
    event_type = models.CharField(max_length=80)
    processed_at = models.DateTimeField(auto_now_add=True)
