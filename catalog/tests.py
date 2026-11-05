from django.test import TestCase
from rest_framework.test import APIClient
from .models import Product

class ProductApiTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        Product.objects.create(
            name="Organic Apples", slug="organic-apples", sku="UDI-APPLE-001",
            price="149.00", stock_quantity="12.500", unit="kg", is_active=True,
        )
        Product.objects.create(
            name="Hidden Item", slug="hidden-item", sku="UDI-HIDDEN-001",
            price="10.00", stock_quantity="1.000", is_active=False,
        )

    def test_list_only_returns_active_products(self):
        response = self.client.get("/api/v1/catalog/products/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["count"], 1)
        self.assertEqual(response.data["results"][0]["sku"], "UDI-APPLE-001")

    def test_product_detail_by_slug(self):
        response = self.client.get("/api/v1/catalog/products/organic-apples/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["stock_quantity"], "12.500")
