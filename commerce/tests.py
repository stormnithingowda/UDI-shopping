from decimal import Decimal
from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework.test import APIClient
from catalog.models import Product
from .models import Address, Cart, CartItem, Order

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
        response = self.client.post("/api/v1/commerce/checkout/", {"address_id": self.address.id}, format="json")
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
        response = self.client.post("/api/v1/commerce/checkout/", {"address_id": foreign_address.id}, format="json")
        self.assertEqual(response.status_code, 404)

class RegistrationTests(TestCase):
    def test_customer_can_register_and_receive_tokens(self):
        response = self.client.post("/api/v1/commerce/register/", {
            "username": "newbuyer", "email": "buyer@example.com", "password": "ValidStrongPass123!"
        }, format="json")
        self.assertEqual(response.status_code, 201)
        self.assertIn("access", response.data)
        self.assertIn("refresh", response.data)

from unittest.mock import patch
from .models import RazorpayPayment

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
            order=self.order, razorpay_order_id="order_test_udi", amount_paise=2000
        )

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

    def test_webhook_rejects_missing_signature_headers(self):
        response = APIClient().post(
            "/api/v1/commerce/payments/razorpay/webhook/",
            data="{}",
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 400)
