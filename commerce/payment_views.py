import hashlib
import hmac
import json
import os
from decimal import Decimal

import razorpay
from django.db import transaction
from django.db.models import F
from django.shortcuts import get_object_or_404
from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from catalog.models import Product
from .models import Order, OrderStatusHistory
from .payment_models import RazorpayPayment, RazorpayWebhookEvent


def _client():
    key_id = os.getenv('RAZORPAY_KEY_ID', '')
    key_secret = os.getenv('RAZORPAY_KEY_SECRET', '')
    if not key_id or not key_secret:
        return None
    return razorpay.Client(auth=(key_id, key_secret))


def _paise(amount):
    return int((amount * Decimal('100')).quantize(Decimal('1')))


class CreateRazorpayOrderView(APIView):
    permission_classes = [IsAuthenticated]
    def post(self, request, order_id):
        order = get_object_or_404(Order, pk=order_id, user=request.user)
        if order.status != Order.Status.PENDING_PAYMENT:
            return Response({'detail': 'This order is not awaiting payment.'}, status=400)
        client = _client()
        if client is None:
            return Response({'detail': 'Razorpay test credentials are not configured on the server.'}, status=503)
        payment, created = RazorpayPayment.objects.get_or_create(
            order=order,
            defaults={'razorpay_order_id': 'pending-' + str(order.pk), 'amount_paise': _paise(order.total_amount)}
        )
        if not created and not payment.razorpay_order_id.startswith('pending-'):
            return Response({'key_id': os.getenv('RAZORPAY_KEY_ID'), 'razorpay_order_id': payment.razorpay_order_id,
                             'amount': payment.amount_paise, 'currency': payment.currency})
        try:
            gateway_order = client.order.create(data={
                'amount': _paise(order.total_amount), 'currency': 'INR', 'receipt': 'udi-order-' + str(order.pk),
                'notes': {'udi_order_id': str(order.pk)}
            })
        except Exception:
            if created:
                payment.delete()
            return Response({'detail': 'Razorpay could not create the payment order.'}, status=502)
        payment.razorpay_order_id = gateway_order['id']
        payment.amount_paise = gateway_order['amount']
        payment.save(update_fields=['razorpay_order_id', 'amount_paise', 'updated_at'])
        return Response({'key_id': os.getenv('RAZORPAY_KEY_ID'), 'razorpay_order_id': payment.razorpay_order_id,
                         'amount': payment.amount_paise, 'currency': payment.currency})


class VerifyRazorpayPaymentView(APIView):
    permission_classes = [IsAuthenticated]
    def post(self, request, order_id):
        order = get_object_or_404(Order, pk=order_id, user=request.user)
        payment = get_object_or_404(RazorpayPayment, order=order)
        payment_id = request.data.get('razorpay_payment_id', '')
        supplied_order_id = request.data.get('razorpay_order_id', '')
        signature = request.data.get('razorpay_signature', '')
        secret = os.getenv('RAZORPAY_KEY_SECRET', '')
        if not all([payment_id, supplied_order_id, signature, secret]):
            return Response({'detail': 'Missing payment verification fields.'}, status=400)
        if supplied_order_id != payment.razorpay_order_id:
            return Response({'detail': 'Payment order does not match.'}, status=400)
        message = (supplied_order_id + '|' + payment_id).encode()
        expected = hmac.new(secret.encode(), message, hashlib.sha256).hexdigest()
        if not hmac.compare_digest(expected, signature):
            return Response({'detail': 'Invalid payment signature.'}, status=400)
        client = _client()
        if client is None:
            return Response({'detail': 'Razorpay is not configured.'}, status=503)
        try:
            gateway_payment = client.payment.fetch(payment_id)
        except Exception:
            return Response({'detail': 'Unable to verify payment with Razorpay.'}, status=502)
        if gateway_payment.get('status') != 'captured' or gateway_payment.get('order_id') != payment.razorpay_order_id:
            return Response({'detail': 'Razorpay has not confirmed a captured payment.'}, status=400)
        if gateway_payment.get('amount') != payment.amount_paise or gateway_payment.get('currency') != 'INR':
            return Response({'detail': 'Payment amount or currency does not match this order.'}, status=400)
        with transaction.atomic():
            order = Order.objects.select_for_update().get(pk=order.pk)
            payment = RazorpayPayment.objects.select_for_update().get(pk=payment.pk)
            if order.status == Order.Status.PENDING_PAYMENT:
                payment.razorpay_payment_id = payment_id
                payment.status = RazorpayPayment.Status.CAPTURED
                payment.save(update_fields=['razorpay_payment_id', 'status', 'updated_at'])
                order.status = Order.Status.CONFIRMED
                order.save(update_fields=['status', 'updated_at'])
                OrderStatusHistory.objects.create(order=order, status=order.status, note='Payment captured and verified with Razorpay.')
        return Response({'detail': 'Payment verified.', 'order_id': order.pk, 'status': order.status})


class RazorpayWebhookView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []
    def post(self, request):
        secret = os.getenv('RAZORPAY_WEBHOOK_SECRET', '')
        signature = request.headers.get('X-Razorpay-Signature', '')
        event_id = request.headers.get('X-Razorpay-Event-Id', '')
        if not secret or not signature or not event_id:
            return Response({'detail': 'Webhook verification headers or secret are missing.'}, status=400)
        expected = hmac.new(secret.encode(), request.body, hashlib.sha256).hexdigest()
        if not hmac.compare_digest(expected, signature):
            return Response({'detail': 'Invalid webhook signature.'}, status=400)
        try:
            payload = json.loads(request.body.decode('utf-8'))
            event_type = payload['event']
        except (ValueError, KeyError, TypeError):
            return Response({'detail': 'Invalid webhook payload.'}, status=400)
        with transaction.atomic():
            event, created = RazorpayWebhookEvent.objects.get_or_create(event_id=event_id, defaults={'event_type': event_type})
            if not created:
                return Response({'detail': 'Event already processed.'}, status=200)
            entity = payload.get('payload', {}).get('payment', {}).get('entity', {})
            gateway_order_id = entity.get('order_id')
            payment = RazorpayPayment.objects.select_for_update().filter(razorpay_order_id=gateway_order_id).select_related('order').first()
            if payment is None:
                event.delete()
                return Response({'detail': 'Payment order not found.'}, status=404)
            order = Order.objects.select_for_update().get(pk=payment.order_id)
            if event_type in ('payment.captured', 'order.paid'):
                if entity.get('amount') != payment.amount_paise or entity.get('currency') != 'INR':
                    event.delete()
                    return Response({'detail': 'Webhook amount or currency mismatch.'}, status=400)
                if order.status == Order.Status.PENDING_PAYMENT:
                    payment.razorpay_payment_id = entity.get('id')
                    payment.status = RazorpayPayment.Status.CAPTURED
                    payment.save(update_fields=['razorpay_payment_id', 'status', 'updated_at'])
                    order.status = Order.Status.CONFIRMED
                    order.save(update_fields=['status', 'updated_at'])
                    OrderStatusHistory.objects.create(order=order, status=order.status, note='Payment captured via verified Razorpay webhook.')
            elif event_type == 'payment.failed' and order.status == Order.Status.PENDING_PAYMENT:
                payment.razorpay_payment_id = entity.get('id')
                payment.status = RazorpayPayment.Status.FAILED
                payment.save(update_fields=['razorpay_payment_id', 'status', 'updated_at'])
                for item in order.items.all():
                    Product.objects.filter(pk=item.product_id).update(stock_quantity=F('stock_quantity') + item.quantity)
                order.status = Order.Status.PAYMENT_FAILED
                order.save(update_fields=['status', 'updated_at'])
                OrderStatusHistory.objects.create(order=order, status=order.status, note='Payment failed; reserved inventory released.')
        return Response({'detail': 'Webhook processed.'}, status=200)
