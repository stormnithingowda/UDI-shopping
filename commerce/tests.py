import hashlib
import hmac
import json
from decimal import Decimal
from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework.test import APIClient

from catalog.models import Product
from .models import (
    Address,
    Cart,
    CartItem,
    Order,
    OrderItem,
    OrderStatusHistory,
    RazorpayPayment,
    RazorpayWebhookEvent,
    WishlistItem,
)


class CheckoutTests(TestCase):
    def setUp(self):
        self.user = get_user_model().objects.create_user(username="buyer", password="StrongPass123!")
        self.client = APIClient()
        self.client.force_authenticate(self.user)
        self.product = Product.objects.create(
            name="Organic Rice", slug="organic-rice", sku="UDI-RICE-001",
            price="80.00", stock_quantity="10.000", unit="kg",
        )
        self.address = Address.objects.create(
            user=self.user, full_name="Test Buyer", phone="9999999999",
            address_line1="1 Test Street", city="Bengaluru", state="Karnataka", postal_code="560001",
        )
        cart, _ = Cart.objects.get_or_create(user=self.user)
        CartItem.objects.create(cart=cart, product=self.product, quantity=Decimal("2.500"))

    def test_checkout_creates_pending_order_and_reserves_stock(self):
        response = self.client.post(
            "/api/v1/commerce/checkout/",
            {"address_id": self.address.id},
            format="json",
        )
        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.data["status"], Order.Status.PENDING_PAYMENT)
        self.product.refresh_from_db()
        self.assertEqual(self.product.stock_quantity, Decimal("7.500"))

    def test_user_cannot_checkout_using_another_users_address(self):
        other = get_user_model().objects.create_user(username="other", password="StrongPass123!")
        foreign_address = Address.objects.create(
            user=other, full_name="Other", phone="9999999998",
            address_line1="2 Other Street", city="Bengaluru", state="Karnataka", postal_code="560002",
        )
        response = self.client.post(
            "/api/v1/commerce/checkout/",
            {"address_id": foreign_address.id},
            format="json",
        )
        self.assertEqual(response.status_code, 404)


class RegistrationTests(TestCase):
    def setUp(self):
        self.client = APIClient()

    def test_customer_can_register_and_receive_tokens(self):
        response = self.client.post("/api/v1/commerce/register/", {
            "username": "newbuyer",
            "email": "buyer@example.com",
            "password": "ValidStrongPass123!",
        }, format="json")
        self.assertEqual(response.status_code, 201)
        self.assertIn("access", response.data)
        self.assertIn("refresh", response.data)


class AddressManagementTests(TestCase):
    def setUp(self):
        self.user = get_user_model().objects.create_user(username="addressbuyer", password="StrongPass123!")
        self.client = APIClient()
        self.client.force_authenticate(self.user)

    def _address_payload(self, name="Address Buyer", is_default=False):
        return {
            "full_name": name,
            "phone": "9999999999",
            "address_line1": "10 Test Road",
            "address_line2": "",
            "city": "Bengaluru",
            "state": "Karnataka",
            "postal_code": "560001",
            "is_default": is_default,
        }

    def test_first_address_becomes_default(self):
        response = self.client.post(
            "/api/v1/commerce/addresses/",
            self._address_payload(),
            format="json",
        )
        self.assertEqual(response.status_code, 201)
        self.assertTrue(response.data["is_default"])

    def test_setting_new_default_unsets_previous_default(self):
        first = self.client.post(
            "/api/v1/commerce/addresses/",
            self._address_payload("First", True),
            format="json",
        )
        second = self.client.post(
            "/api/v1/commerce/addresses/",
            self._address_payload("Second", False),
            format="json",
        )
        response = self.client.patch(
            f"/api/v1/commerce/addresses/{second.data['id']}/",
            {"is_default": True},
            format="json",
        )
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.data["is_default"])
        self.assertFalse(
            Address.objects.get(pk=first.data["id"]).is_default
        )

    def test_address_linked_to_order_cannot_be_deleted(self):
        address = Address.objects.create(
            user=self.user,
            full_name="Order Buyer",
            phone="9999999999",
            address_line1="11 Order Road",
            city="Bengaluru",
            state="Karnataka",
            postal_code="560001",
        )
        Order.objects.create(user=self.user, address=address, total_amount=Decimal("10.00"))
        response = self.client.delete(f"/api/v1/commerce/addresses/{address.id}/")
        self.assertEqual(response.status_code, 400)

    def test_customer_can_delete_unused_address(self):
        address = Address.objects.create(
            user=self.user,
            full_name="Temporary",
            phone="9999999999",
            address_line1="12 Delete Road",
            city="Bengaluru",
            state="Karnataka",
            postal_code="560001",
        )
        response = self.client.delete(f"/api/v1/commerce/addresses/{address.id}/")
        self.assertEqual(response.status_code, 204)
        self.assertFalse(Address.objects.filter(pk=address.id).exists())

    def test_address_linked_to_order_cannot_be_edited(self):
        address = Address.objects.create(
            user=self.user,
            full_name="Historical Address",
            phone="9999999999",
            address_line1="13 History Road",
            city="Bengaluru",
            state="Karnataka",
            postal_code="560001",
        )
        Order.objects.create(user=self.user, address=address, total_amount=Decimal("10.00"))
        response = self.client.patch(
            f"/api/v1/commerce/addresses/{address.id}/",
            {"address_line1": "Changed Road"},
            format="json",
        )
        self.assertEqual(response.status_code, 400)
        address.refresh_from_db()
        self.assertEqual(address.address_line1, "13 History Road")


class PaymentSecurityTests(TestCase):
    def setUp(self):
        self.user = get_user_model().objects.create_user(username="payer", password="StrongPass123!")
        self.client = APIClient()
        self.client.force_authenticate(self.user)
        address = Address.objects.create(
            user=self.user, full_name="Test Payer", phone="9999999997",
            address_line1="3 Payment Road", city="Bengaluru", state="Karnataka", postal_code="560003",
        )
        self.order = Order.objects.create(user=self.user, address=address, total_amount=Decimal("20.00"))
        self.payment = RazorpayPayment.objects.create(
            order=self.order,
            razorpay_order_id="order_test_udi",
            amount_paise=2000,
        )

    @patch.dict("os.environ", {"RAZORPAY_KEY_SECRET": "test_secret", "RAZORPAY_KEY_ID": "rzp_test_key"})
    def test_payment_create_returns_flutter_checkout_contract(self):
        response = self.client.post(
            f"/api/v1/commerce/orders/{self.order.id}/payment/create/",
            {},
            format="json",
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            set(response.data),
            {"key_id", "razorpay_order_id", "amount", "currency"},
        )
        self.assertEqual(response.data["key_id"], "rzp_test_key")
        self.assertEqual(response.data["amount"], 2000)
        self.assertEqual(response.data["currency"], "INR")

    @patch.dict("os.environ", {"RAZORPAY_KEY_SECRET": "live_secret", "RAZORPAY_KEY_ID": "rzp_live_not_allowed"})
    def test_live_razorpay_key_is_rejected_by_test_mode_backend(self):
        response = self.client.post(
            f"/api/v1/commerce/orders/{self.order.id}/payment/create/",
            {},
            format="json",
        )
        self.assertEqual(response.status_code, 503)

    @patch.dict("os.environ", {"RAZORPAY_KEY_SECRET": "test_secret", "RAZORPAY_KEY_ID": "rzp_test_key"})
    def test_invalid_signature_cannot_confirm_order(self):
        response = self.client.post(
            f"/api/v1/commerce/orders/{self.order.id}/payment/verify/",
            {
                "razorpay_payment_id": "pay_test_udi",
                "razorpay_order_id": "order_test_udi",
                "razorpay_signature": "not-a-valid-signature",
            },
            format="json",
        )
        self.assertEqual(response.status_code, 400)
        self.order.refresh_from_db()
        self.assertEqual(self.order.status, Order.Status.PENDING_PAYMENT)

    @patch.dict("os.environ", {"RAZORPAY_KEY_SECRET": "test_secret", "RAZORPAY_KEY_ID": "rzp_test_key"})
    def test_valid_signature_and_captured_gateway_status_confirm_order(self):
        payment_id = "pay_test_udi"
        signature = hmac.new(
            b"test_secret",
            f"order_test_udi|{payment_id}".encode(),
            hashlib.sha256,
        ).hexdigest()
        with patch("commerce.payment_views._client") as client_factory:
            client_factory.return_value.payment.fetch.return_value = {
                "id": payment_id,
                "order_id": "order_test_udi",
                "status": "captured",
                "amount": 2000,
                "currency": "INR",
            }
            response = self.client.post(
                f"/api/v1/commerce/orders/{self.order.id}/payment/verify/",
                {
                    "razorpay_payment_id": payment_id,
                    "razorpay_order_id": "order_test_udi",
                    "razorpay_signature": signature,
                },
                format="json",
            )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["status"], Order.Status.CONFIRMED)
        self.order.refresh_from_db()
        self.payment.refresh_from_db()
        self.assertEqual(self.order.status, Order.Status.CONFIRMED)
        self.assertEqual(self.payment.status, RazorpayPayment.Status.CAPTURED)
        self.assertEqual(OrderStatusHistory.objects.filter(order=self.order).count(), 1)

    def test_webhook_rejects_missing_signature_headers(self):
        response = APIClient().post(
            "/api/v1/commerce/payments/razorpay/webhook/",
            data="{}",
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 400)

    @patch.dict("os.environ", {"RAZORPAY_WEBHOOK_SECRET": "webhook_secret"})
    def test_webhook_rejects_invalid_signature_without_recording_event(self):
        response = APIClient().generic(
            "POST",
            "/api/v1/commerce/payments/razorpay/webhook/",
            b"{}",
            content_type="application/json",
            HTTP_X_RAZORPAY_SIGNATURE="invalid",
            HTTP_X_RAZORPAY_EVENT_ID="evt_udi_invalid_001",
        )
        self.assertEqual(response.status_code, 400)
        self.assertFalse(
            RazorpayWebhookEvent.objects.filter(event_id="evt_udi_invalid_001").exists()
        )

    @patch.dict("os.environ", {"RAZORPAY_WEBHOOK_SECRET": "webhook_secret"})
    def test_signed_captured_webhook_confirms_order_and_deduplicates_event(self):
        payload = {
            "event": "payment.captured",
            "payload": {
                "payment": {
                    "entity": {
                        "id": "pay_webhook_udi",
                        "order_id": "order_test_udi",
                        "amount": 2000,
                        "currency": "INR",
                    }
                }
            },
        }
        body = json.dumps(payload).encode("utf-8")
        signature = hmac.new(b"webhook_secret", body, hashlib.sha256).hexdigest()
        headers = {
            "HTTP_X_RAZORPAY_SIGNATURE": signature,
            "HTTP_X_RAZORPAY_EVENT_ID": "evt_udi_captured_001",
        }
        first = APIClient().generic(
            "POST",
            "/api/v1/commerce/payments/razorpay/webhook/",
            body,
            content_type="application/json",
            **headers,
        )
        second = APIClient().generic(
            "POST",
            "/api/v1/commerce/payments/razorpay/webhook/",
            body,
            content_type="application/json",
            **headers,
        )
        self.assertEqual(first.status_code, 200)
        self.assertEqual(second.status_code, 200)
        self.order.refresh_from_db()
        self.assertEqual(self.order.status, Order.Status.CONFIRMED)
        self.assertEqual(RazorpayWebhookEvent.objects.filter(event_id="evt_udi_captured_001").count(), 1)
        self.assertEqual(OrderStatusHistory.objects.filter(order=self.order).count(), 1)

    @patch.dict("os.environ", {"RAZORPAY_WEBHOOK_SECRET": "webhook_secret"})
    def test_signed_payment_failed_webhook_keeps_order_pending_for_retry(self):
        payload = {
            "event": "payment.failed",
            "payload": {
                "payment": {
                    "entity": {
                        "id": "pay_failed_udi",
                        "order_id": "order_test_udi",
                        "amount": 2000,
                        "currency": "INR",
                    }
                }
            },
        }
        body = json.dumps(payload).encode("utf-8")
        signature = hmac.new(b"webhook_secret", body, hashlib.sha256).hexdigest()
        response = APIClient().generic(
            "POST",
            "/api/v1/commerce/payments/razorpay/webhook/",
            body,
            content_type="application/json",
            HTTP_X_RAZORPAY_SIGNATURE=signature,
            HTTP_X_RAZORPAY_EVENT_ID="evt_udi_failed_001",
        )
        self.assertEqual(response.status_code, 200)
        self.order.refresh_from_db()
        self.payment.refresh_from_db()
        self.assertEqual(self.order.status, Order.Status.PENDING_PAYMENT)
        self.assertEqual(self.payment.status, RazorpayPayment.Status.FAILED)
        self.assertEqual(OrderStatusHistory.objects.filter(order=self.order).count(), 1)


class CartAndWishlistTests(TestCase):
    def setUp(self):
        self.user = get_user_model().objects.create_user(username="shopper", password="StrongPass123!")
        self.client = APIClient()
        self.client.force_authenticate(self.user)
        self.product = Product.objects.create(
            name="Organic Apples", slug="organic-apples", sku="UDI-APPLE-001",
            price="120.00", stock_quantity="5.000", unit="kg",
        )
        self.cart, _ = Cart.objects.get_or_create(user=self.user)

    def test_customer_can_update_cart_quantity(self):
        item = CartItem.objects.create(cart=self.cart, product=self.product, quantity=Decimal("1.000"))
        response = self.client.patch(
            f"/api/v1/commerce/cart/items/{item.id}/",
            {"quantity": "2.250"},
            format="json",
        )
        self.assertEqual(response.status_code, 200)
        item.refresh_from_db()
        self.assertEqual(item.quantity, Decimal("2.250"))

    def test_customer_cannot_set_cart_quantity_above_stock(self):
        item = CartItem.objects.create(cart=self.cart, product=self.product, quantity=Decimal("1.000"))
        response = self.client.patch(
            f"/api/v1/commerce/cart/items/{item.id}/",
            {"quantity": "6.000"},
            format="json",
        )
        self.assertEqual(response.status_code, 400)
        item.refresh_from_db()
        self.assertEqual(item.quantity, Decimal("1.000"))

    def test_wishlist_product_can_be_moved_to_cart(self):
        saved = WishlistItem.objects.create(user=self.user, product=self.product)
        response = self.client.post(
            f"/api/v1/commerce/wishlist/{saved.id}/move-to-cart/",
            {"quantity": "1.500"},
            format="json",
        )
        self.assertEqual(response.status_code, 201)
        self.assertTrue(
            CartItem.objects.filter(
                cart=self.cart,
                product=self.product,
                quantity=Decimal("1.500"),
            ).exists()
        )

    def test_wishlist_move_rejects_excess_stock_without_creating_cart_item(self):
        saved = WishlistItem.objects.create(user=self.user, product=self.product)
        response = self.client.post(
            f"/api/v1/commerce/wishlist/{saved.id}/move-to-cart/",
            {"quantity": "6.000"},
            format="json",
        )
        self.assertEqual(response.status_code, 400)
        self.assertFalse(CartItem.objects.filter(cart=self.cart, product=self.product).exists())
